package main

import (
	"encoding/json"
	"flag"
	"fmt"
	"net"
	"os"
	"time"

	"github.com/hashicorp/consul/api"
	hclog "github.com/hashicorp/go-hclog"
)

type Config struct {
	Service          api.AgentService `json:"service"`
	RegisterInterval string           `json:"register_interval"`
}

type MockService struct {
	Config Config
	Logger hclog.Logger

	registration *api.CatalogRegistration
}

func (m *MockService) buildRegistration() bool {
	nodeName, err := os.Hostname()
	if err != nil {
		m.Logger.Error("Failed to get the hostname", "err", err)
		return false
	}

	addresses, err := GetPrivateIPv4()
	if err != nil {
		m.Logger.Error("Failed to find an IP address for ourselves", "err", err)
		return false
	}
	if len(addresses) < 1 {
		m.Logger.Error("Failed to find any IP addresses")
		return false
	}

	m.registration = &api.CatalogRegistration{
		Node:    nodeName,
		Address: addresses[0].String(),
		Service: &m.Config.Service,
		Check: &api.AgentCheck{
			Node:   nodeName,
			Name:   "Node TTL",
			Status: "passing",
		},
	}
	return true
}

func (m *MockService) run() int {
	if !m.buildRegistration() {
		return 1
	}

	m.Logger.Info("Registration Generated", "registration", m.registration)

	if m.Config.RegisterInterval == "" {
		m.Config.RegisterInterval = "5s"
	}

	interval, err := time.ParseDuration(m.Config.RegisterInterval)
	if err != nil {
		m.Logger.Warn("Failed to parse register interval - defaulting to 5s", "err", err)
		interval = 5 * time.Second
	}

	client, err := api.NewClient(api.DefaultConfig())
	if err != nil {
		m.Logger.Error("Failed to create Consul API client", "err", err)
		return 1
	}

	catalog := client.Catalog()

	for {
		select {
		case <-time.After(interval):
			_, err := catalog.Register(m.registration, nil)
			if err != nil {
				m.Logger.Error("Failed to register service", "err", err)
			} else {
				m.Logger.Info("Service registration successful")
			}
		}
	}

	return 0
}

func main() {
	logger := hclog.New(&hclog.LoggerOptions{
		Name:  "consul-mock-service",
		Level: hclog.LevelFromString("DEBUG"),
	})

	var configPath string
	flag.StringVar(&configPath, "config", "/consul-mock-service.json", "Path to the configuration")
	flag.Parse()

	file, err := os.Open(configPath)
	if err != nil {
		logger.Error("Failed to open configuration file", "path", configPath, "err", err)
		os.Exit(1)
	}

	var config Config
	decoder := json.NewDecoder(file)
	if err := decoder.Decode(&config); err != nil {
		logger.Error("Failed to decode configuration file", "path", configPath, "err", err)
		os.Exit(1)
	}

	m := MockService{Config: config, Logger: logger}
	os.Exit(m.run())
}

// GetPrivateIPv4 returns the list of private network IPv4 addresses on
// all active interfaces.
func GetPrivateIPv4() ([]*net.IPAddr, error) {
	addresses, err := activeInterfaceAddresses()
	if err != nil {
		return nil, fmt.Errorf("Failed to get interface addresses: %v", err)
	}

	var addrs []*net.IPAddr
	for _, rawAddr := range addresses {
		var ip net.IP
		switch addr := rawAddr.(type) {
		case *net.IPAddr:
			ip = addr.IP
		case *net.IPNet:
			ip = addr.IP
		default:
			continue
		}
		if ip.To4() == nil {
			continue
		}
		if !isPrivate(ip) {
			continue
		}
		addrs = append(addrs, &net.IPAddr{IP: ip})
	}
	return addrs, nil
}

// privateBlocks contains non-forwardable address blocks which are used
// for private networks. RFC 6890 provides an overview of special
// address blocks.
var privateBlocks = []*net.IPNet{
	parseCIDR("10.0.0.0/8"),     // RFC 1918 IPv4 private network address
	parseCIDR("100.64.0.0/10"),  // RFC 6598 IPv4 shared address space
	parseCIDR("127.0.0.0/8"),    // RFC 1122 IPv4 loopback address
	parseCIDR("169.254.0.0/16"), // RFC 3927 IPv4 link local address
	parseCIDR("172.16.0.0/12"),  // RFC 1918 IPv4 private network address
	parseCIDR("192.0.0.0/24"),   // RFC 6890 IPv4 IANA address
	parseCIDR("192.0.2.0/24"),   // RFC 5737 IPv4 documentation address
	parseCIDR("192.168.0.0/16"), // RFC 1918 IPv4 private network address
	parseCIDR("::1/128"),        // RFC 1884 IPv6 loopback address
	parseCIDR("fe80::/10"),      // RFC 4291 IPv6 link local addresses
	parseCIDR("fc00::/7"),       // RFC 4193 IPv6 unique local addresses
	parseCIDR("fec0::/10"),      // RFC 1884 IPv6 site-local addresses
	parseCIDR("2001:db8::/32"),  // RFC 3849 IPv6 documentation address
}

func parseCIDR(s string) *net.IPNet {
	_, block, err := net.ParseCIDR(s)
	if err != nil {
		panic(fmt.Sprintf("Bad CIDR %s: %s", s, err))
	}
	return block
}

func isPrivate(ip net.IP) bool {
	for _, priv := range privateBlocks {
		if priv.Contains(ip) {
			return true
		}
	}
	return false
}

// Returns addresses from interfaces that is up
func activeInterfaceAddresses() ([]net.Addr, error) {
	var upAddrs []net.Addr
	var loAddrs []net.Addr

	interfaces, err := net.Interfaces()
	if err != nil {
		return nil, fmt.Errorf("Failed to get interfaces: %v", err)
	}

	for _, iface := range interfaces {
		// Require interface to be up
		if iface.Flags&net.FlagUp == 0 {
			continue
		}

		addresses, err := iface.Addrs()
		if err != nil {
			return nil, fmt.Errorf("Failed to get interface addresses: %v", err)
		}

		if iface.Flags&net.FlagLoopback != 0 {
			loAddrs = append(loAddrs, addresses...)
			continue
		}

		upAddrs = append(upAddrs, addresses...)
	}

	if len(upAddrs) == 0 {
		return loAddrs, nil
	}

	return upAddrs, nil
}
