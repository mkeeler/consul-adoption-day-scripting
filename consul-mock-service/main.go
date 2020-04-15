package main

import (
	"encoding/json"
	"flag"
	"fmt"
	"net"
	"os"
	"strconv"
	"strings"
	"time"

	"github.com/hashicorp/consul/api"
	hclog "github.com/hashicorp/go-hclog"
)

type KVOp struct {
	Op        string `json:"op"`
	Key       string `json:"key"`
	Value     string `json:"value"`
	Namespace string `json:"namespace"`
}

type Upstream struct {
	Service   string `json:"service"`
	Namespace string `json:"namespace"`
}

type Config struct {
	UseAgentAPI       bool             `json:"use_agent_api"`
	Service           api.AgentService `json:"service"`
	RegisterInterval  string           `json:"register_interval"`
	UpstreamServices  []Upstream       `json:"upstream_services"`
	DiscoveryInterval string           `json:"discovery_interval"`
	KVOps             []KVOp           `json:"kv_ops"`
}

type MockService struct {
	Config Config
	Logger hclog.Logger

	client              *api.Client
	catalogRegistration *api.CatalogRegistration
	agentRegistration   *api.AgentServiceRegistration
	namespace           string
}

func prettyErrors(err error) error {
	if rawErrors, _ := strconv.ParseBool(os.Getenv("MOCK_RAW_ERRORS")); rawErrors {
		return err
	}

	msg := err.Error()
	if strings.Contains(msg, "Permission denied") || strings.Contains(msg, "Unexpected response code: 403") {
		return fmt.Errorf("Permission Denied")
	}
	return err
}

func (m *MockService) namespaced(service string, ns string) string {
	if m.namespace == "" {
		return service
	}

	if ns == "" {
		ns = m.namespace
	}

	if ns != "" {
		return fmt.Sprintf("%s/%s", ns, service)
	}
	return service
}

func (m *MockService) buildRegistrations() bool {
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

	svc := &m.Config.Service

	m.catalogRegistration = &api.CatalogRegistration{
		Node:    nodeName,
		Address: addresses[0].String(),
		Service: svc,
		Checks: api.HealthChecks{
			&api.HealthCheck{
				Node:      nodeName,
				Name:      "Node TTL",
				Status:    "passing",
				Namespace: "default",
			},
			&api.HealthCheck{
				Node:        nodeName,
				Name:        "Service Check",
				Status:      "passing",
				ServiceName: svc.Service,
				Type:        "ttl",
			},
		},
	}

	var weights *api.AgentWeights

	if svc.Weights.Passing > 0 && svc.Weights.Warning > 0 {
		weights = &svc.Weights
	}

	m.agentRegistration = &api.AgentServiceRegistration{
		Kind:              svc.Kind,
		ID:                fmt.Sprintf("%s:%s", svc.Service, nodeName),
		Name:              svc.Service,
		Port:              svc.Port,
		Address:           addresses[0].String(),
		TaggedAddresses:   svc.TaggedAddresses,
		EnableTagOverride: svc.EnableTagOverride,
		Meta:              svc.Meta,
		Weights:           weights,
		Proxy:             svc.Proxy,
		Connect:           svc.Connect,
		Namespace:         svc.Namespace,
	}
	return true
}

func (m *MockService) register(interval time.Duration) {
	catalog := m.client.Catalog()
	agent := m.client.Agent()

	waitTime := 0 * time.Second
	for {
		select {
		case <-time.After(waitTime):
			waitTime = interval
			var err error
			if m.Config.UseAgentAPI {
				err = agent.ServiceRegister(m.agentRegistration)
			} else {
				_, err = catalog.Register(m.catalogRegistration, nil)
			}
			if err != nil {
				m.Logger.Error("Failed to register service", "err", prettyErrors(err))
			} else {
				m.Logger.Info("Service registration successful")
				return
			}
		}
	}
}

func (m *MockService) QueryOptions(ns string) *api.QueryOptions {
	if m.namespace == ns || m.namespace == "" {
		return nil
	}

	return &api.QueryOptions{
		Namespace: ns,
	}
}

func (m *MockService) WriteOptions(ns string) *api.WriteOptions {
	if m.namespace == ns || m.namespace == "" {
		return nil
	}

	return &api.WriteOptions{
		Namespace: ns,
	}
}

func (m *MockService) discover(interval time.Duration) {
	catalog := m.client.Catalog()
	kv := m.client.KV()

	useDisco, _ := strconv.ParseBool(os.Getenv("MOCK_USE_DISCO"))
	useKV, _ := strconv.ParseBool(os.Getenv("MOCK_USE_KV"))

	waitTime := 0 * time.Second
	for {
		select {
		case <-time.After(waitTime):
			waitTime = interval
			if useDisco {
				for _, svc := range m.Config.UpstreamServices {
					services, _, err := catalog.Service(svc.Service, "", m.QueryOptions(svc.Namespace))

					if err != nil {
						m.Logger.Error("Failed to discover service", "name", m.namespaced(svc.Service, svc.Namespace), "err", prettyErrors(err))
					} else {
						m.Logger.Info("Service discovery completed", "name", m.namespaced(svc.Service, svc.Namespace), "count", len(services))
					}
				}
			}

			if useKV {
				for _, op := range m.Config.KVOps {
					if op.Op == "write" {

						apiPair := api.KVPair{Key: op.Key, Value: []byte(op.Value)}

						_, err := kv.Put(&apiPair, m.WriteOptions(op.Namespace))
						if err != nil {
							m.Logger.Error("Failed to write KV pair", "key", m.namespaced(op.Key, op.Namespace), "err", prettyErrors(err))
						} else {
							m.Logger.Info("Wrote KV pair", "key", m.namespaced(op.Key, op.Namespace))
						}
					} else {
						pair, _, err := kv.Get(op.Key, m.QueryOptions(op.Namespace))
						if err != nil {
							m.Logger.Error("Failed to read KV data", "key", m.namespaced(op.Key, op.Namespace), "err", prettyErrors(err))
						} else {
							m.Logger.Info("KV", "key", m.namespaced(op.Key, op.Namespace), "value", string(pair.Value))
						}
					}
				}
			}
		}
	}
}

func (m *MockService) run() int {
	m.namespace = os.Getenv("CONSUL_NAMESPACE")

	if !m.buildRegistrations() {
		return 1
	}

	if m.Config.UseAgentAPI {
		m.Logger.Info("Registration Generated", "service", m.namespaced(m.agentRegistration.Name, m.namespace))
	} else {
		m.Logger.Info("Registration Generated", "node", m.catalogRegistration.Node, "service", m.namespaced(m.agentRegistration.Name, m.namespace))
	}

	if m.Config.RegisterInterval == "" {
		m.Config.RegisterInterval = "5s"
	}
	if m.Config.DiscoveryInterval == "" {
		m.Config.DiscoveryInterval = "5s"
	}

	registerInterval, err := time.ParseDuration(m.Config.RegisterInterval)
	if err != nil {
		m.Logger.Warn("Failed to parse register interval - defaulting to 5s", "err", prettyErrors(err))
		registerInterval = 5 * time.Second
	}

	discoveryInterval, err := time.ParseDuration(m.Config.DiscoveryInterval)
	if err != nil {
		m.Logger.Warn("Failed to parse discovery interval - defaulting to 5s", "err", prettyErrors(err))
		discoveryInterval = 5 * time.Second
	}

	client, err := api.NewClient(api.DefaultConfig())
	if err != nil {
		m.Logger.Error("Failed to create Consul API client", "err", prettyErrors(err))
		return 1
	}

	m.client = client

	m.register(registerInterval)
	m.discover(discoveryInterval)

	return 0
}

func main() {
	logger := hclog.New(&hclog.LoggerOptions{
		Level:      hclog.LevelFromString("DEBUG"),
		TimeFormat: "15:04:05",
	})

	var configPath string
	flag.StringVar(&configPath, "config", "/consul-mock-service.json", "Path to the configuration")
	flag.Parse()

	file, err := os.Open(configPath)
	if err != nil {
		logger.Error("Failed to open configuration file", "path", configPath, "err", prettyErrors(err))
		os.Exit(1)
	}

	var config Config
	decoder := json.NewDecoder(file)
	if err := decoder.Decode(&config); err != nil {
		logger.Error("Failed to decode configuration file", "path", configPath, "err", prettyErrors(err))
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
