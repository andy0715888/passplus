package xray

import (
	"bytes"
	"encoding/json"
	"x-ui/database/model"
	"x-ui/util/json_util"
)

type Config struct {
	LogConfig       json_util.RawMessage `json:"log"`
	RouterConfig    json_util.RawMessage `json:"routing"`
	DNSConfig       json_util.RawMessage `json:"dns"`
	InboundConfigs  []model.InboundConfig `json:"inbounds"`
	OutboundConfigs json_util.RawMessage `json:"outbounds"`
	Transport       json_util.RawMessage `json:"transport"`
	Policy          json_util.RawMessage `json:"policy"`
	API             json_util.RawMessage `json:"api"`
	Stats           json_util.RawMessage `json:"stats"`
	Reverse         json_util.RawMessage `json:"reverse"`
	FakeDNS         json_util.RawMessage `json:"fakeDns"`
}

func (c *Config) Equals(other *Config) bool {
	if len(c.InboundConfigs) != len(other.InboundConfigs) {
		return false
	}
	for i, inbound := range c.InboundConfigs {
		if !InboundConfigEquals(&inbound, &other.InboundConfigs[i]) {
			return false
		}
	}
	if !bytes.Equal(c.LogConfig, other.LogConfig) {
		return false
	}
	if !bytes.Equal(c.RouterConfig, other.RouterConfig) {
		return false
	}
	if !bytes.Equal(c.DNSConfig, other.DNSConfig) {
		return false
	}
	if !bytes.Equal(c.OutboundConfigs, other.OutboundConfigs) {
		return false
	}
	if !bytes.Equal(c.Transport, other.Transport) {
		return false
	}
	if !bytes.Equal(c.Policy, other.Policy) {
		return false
	}
	if !bytes.Equal(c.API, other.API) {
		return false
	}
	if !bytes.Equal(c.Stats, other.Stats) {
		return false
	}
	if !bytes.Equal(c.Reverse, other.Reverse) {
		return false
	}
	if !bytes.Equal(c.FakeDNS, other.FakeDNS) {
		return false
	}
	return true
}

// BuildConfig 构建完整的Xray配置
func (c *Config) BuildConfig() map[string]interface{} {
	config := make(map[string]interface{})
	
	// 添加基本配置
	if len(c.LogConfig) > 0 {
		var logConfig interface{}
		json.Unmarshal(c.LogConfig, &logConfig)
		config["log"] = logConfig
	}
	
	if len(c.RouterConfig) > 0 {
		var routerConfig interface{}
		json.Unmarshal(c.RouterConfig, &routerConfig)
		config["routing"] = routerConfig
	}
	
	if len(c.DNSConfig) > 0 {
		var dnsConfig interface{}
		json.Unmarshal(c.DNSConfig, &dnsConfig)
		config["dns"] = dnsConfig
	}
	
	// 添加入站配置
	var inbounds []interface{}
	var secondaryForwardOutbounds []interface{}
	var routingRules []interface{}
	
	for i := range c.InboundConfigs {
		inbound := &c.InboundConfigs[i]
		
		// 应用二次转发设置到inbound配置
		ApplySecondaryForward(inbound)
		
		// 添加入站配置
		inboundMap := map[string]interface{}{
			"listen":         json.RawMessage(inbound.Listen),
			"port":           inbound.Port,
			"protocol":       inbound.Protocol,
			"settings":       json.RawMessage(inbound.Settings),
			"streamSettings": json.RawMessage(inbound.StreamSettings),
			"tag":            inbound.Tag,
			"sniffing":       json.RawMessage(inbound.Sniffing),
		}
		inbounds = append(inbounds, inboundMap)
		
		// 如果有二次转发，添加出站配置
		if inbound.SecondaryForwardEnable && inbound.SecondaryForwardProtocol != "" && inbound.SecondaryForwardProtocol != "none" {
			outboundJSON, outboundTag := GetSecondaryForwardOutbound(inbound)
			if outboundJSON != nil && outboundTag != "" {
				// 添加出站配置
				var outbound interface{}
				json.Unmarshal(outboundJSON, &outbound)
				secondaryForwardOutbounds = append(secondaryForwardOutbounds, outbound)
				
				// 添加路由规则
				rule := map[string]interface{}{
					"type":        "field",
					"inboundTag":  []string{inbound.Tag},
					"outboundTag": outboundTag,
				}
				routingRules = append(routingRules, rule)
			}
		}
	}
	
	config["inbounds"] = inbounds
	
	// 处理出站配置
	var outbounds []interface{}
	
	// 先添加现有的出站配置
	if len(c.OutboundConfigs) > 0 {
		var existingOutbounds []interface{}
		json.Unmarshal(c.OutboundConfigs, &existingOutbounds)
		outbounds = append(outbounds, existingOutbounds...)
	}
	
	// 添加二次转发出站配置
	if len(secondaryForwardOutbounds) > 0 {
		outbounds = append(outbounds, secondaryForwardOutbounds...)
	}
	
	if len(outbounds) > 0 {
		config["outbounds"] = outbounds
	}
	
	// 添加路由规则
	if len(routingRules) > 0 {
		c.updateRoutingConfig(config, routingRules)
	}
	
	// 添加其他配置
	if len(c.Transport) > 0 {
		var transport interface{}
		json.Unmarshal(c.Transport, &transport)
		config["transport"] = transport
	}
	
	if len(c.Policy) > 0 {
		var policy interface{}
		json.Unmarshal(c.Policy, &policy)
		config["policy"] = policy
	}
	
	if len(c.API) > 0 {
		var api interface{}
		json.Unmarshal(c.API, &api)
		config["api"] = api
	}
	
	if len(c.Stats) > 0 {
		var stats interface{}
		json.Unmarshal(c.Stats, &stats)
		config["stats"] = stats
	}
	
	if len(c.Reverse) > 0 {
		var reverse interface{}
		json.Unmarshal(c.Reverse, &reverse)
		config["reverse"] = reverse
	}
	
	if len(c.FakeDNS) > 0 {
		var fakeDNS interface{}
		json.Unmarshal(c.FakeDNS, &fakeDNS)
		config["fakeDns"] = fakeDNS
	}
	
	return config
}

// updateRoutingConfig 更新路由配置，添加二次转发规则
func (c *Config) updateRoutingConfig(config map[string]interface{}, newRules []interface{}) {
	// 获取现有的路由配置
	var routing map[string]interface{}
	if len(c.RouterConfig) > 0 {
		json.Unmarshal(c.RouterConfig, &routing)
	} else {
		routing = make(map[string]interface{})
	}
	
	// 确保rules存在
	var rules []interface{}
	if existingRules, ok := routing["rules"]; ok {
		if existingSlice, ok := existingRules.([]interface{}); ok {
			rules = existingSlice
		}
	}
	
	// 添加新的路由规则
	rules = append(rules, newRules...)
	routing["rules"] = rules
	
	// 更新路由配置
	routingJSON, err := json.Marshal(routing)
	if err == nil {
		config["routing"] = json.RawMessage(routingJSON)
	}
}
