package xray

import (
	"bytes"
	"encoding/json"
	"fmt"
	"x-ui/database/model"
	"x-ui/util/json_util"
)

// InboundConfigEquals 比较两个InboundConfig是否相等
func InboundConfigEquals(c, other *model.InboundConfig) bool {
	if !bytes.Equal(c.Listen, other.Listen) {
		return false
	}
	if c.Port != other.Port {
		return false
	}
	if c.Protocol != other.Protocol {
		return false
	}
	if !bytes.Equal(c.Settings, other.Settings) {
		return false
	}
	if !bytes.Equal(c.StreamSettings, other.StreamSettings) {
		return false
	}
	if c.Tag != other.Tag {
		return false
	}
	if !bytes.Equal(c.Sniffing, other.Sniffing) {
		return false
	}
	
	// 比较二次转发配置
	if c.SecondaryForwardEnable != other.SecondaryForwardEnable {
		return false
	}
	if c.SecondaryForwardProtocol != other.SecondaryForwardProtocol {
		return false
	}
	if c.SecondaryForwardAddress != other.SecondaryForwardAddress {
		return false
	}
	if c.SecondaryForwardPort != other.SecondaryForwardPort {
		return false
	}
	if c.SecondaryForwardUsername != other.SecondaryForwardUsername {
		return false
	}
	if c.SecondaryForwardPassword != other.SecondaryForwardPassword {
		return false
	}
	
	return true
}

// ApplySecondaryForward 应用二次转发配置到settings
func ApplySecondaryForward(c *model.InboundConfig) {
	if !c.SecondaryForwardEnable || c.SecondaryForwardProtocol == "" {
		return
	}
	
	// 根据协议类型应用二次转发配置
	switch c.SecondaryForwardProtocol {
	case "socks":
		applySocksForward(c)
	case "http":
		applyHTTPForward(c)
	}
}

// applySocksForward 应用SOCKS二次转发
func applySocksForward(c *model.InboundConfig) {
	// 解析现有的settings
	var settings map[string]interface{}
	if len(c.Settings) > 0 {
		json.Unmarshal(c.Settings, &settings)
	} else {
		settings = make(map[string]interface{})
	}
	
	// 添加SOCKS代理设置 - Xray的proxySettings格式
	proxySettings := map[string]interface{}{
		"proxySettings": map[string]interface{}{
			"tag": fmt.Sprintf("socks-forward-%d", c.Port),
		},
	}
	
	// 合并设置
	for k, v := range proxySettings {
		settings[k] = v
	}
	
	// 更新settings
	updatedSettings, _ := json.Marshal(settings)
	c.Settings = updatedSettings
}

// applyHTTPForward 应用HTTP二次转发
func applyHTTPForward(c *model.InboundConfig) {
	// 解析现有的settings
	var settings map[string]interface{}
	if len(c.Settings) > 0 {
		json.Unmarshal(c.Settings, &settings)
	} else {
		settings = make(map[string]interface{})
	}
	
	// 添加HTTP代理设置
	proxySettings := map[string]interface{}{
		"proxySettings": map[string]interface{}{
			"tag": fmt.Sprintf("http-forward-%d", c.Port),
		},
	}
	
	// 合并设置
	for k, v := range proxySettings {
		settings[k] = v
	}
	
	// 更新settings
	updatedSettings, _ := json.Marshal(settings)
	c.Settings = updatedSettings
}

// GetSecondaryForwardOutbound 获取二次转发出站配置
func GetSecondaryForwardOutbound(c *model.InboundConfig) (json_util.RawMessage, string) {
	if !c.SecondaryForwardEnable || c.SecondaryForwardProtocol == "" {
		return nil, ""
	}
	
	var outbound map[string]interface{}
	var tag string
	
	switch c.SecondaryForwardProtocol {
	case "socks":
		tag = fmt.Sprintf("socks-forward-%d", c.Port)
		
		// 构建用户数组
		var users []map[string]interface{}
		if c.SecondaryForwardUsername != "" && c.SecondaryForwardPassword != "" {
			users = append(users, map[string]interface{}{
				"user": c.SecondaryForwardUsername,
				"pass": c.SecondaryForwardPassword,
			})
		}
		
		outbound = map[string]interface{}{
			"protocol": "socks",
			"settings": map[string]interface{}{
				"servers": []map[string]interface{}{
					{
						"address": c.SecondaryForwardAddress,
						"port":    c.SecondaryForwardPort,
					},
				},
			},
			"tag": tag,
		}
		
		// 如果有认证信息，添加到服务器配置
		if len(users) > 0 {
			outbound["settings"].(map[string]interface{})["servers"].([]map[string]interface{})[0]["users"] = users
		}
		
	case "http":
		tag = fmt.Sprintf("http-forward-%d", c.Port)
		
		// 构建用户数组
		var users []map[string]interface{}
		if c.SecondaryForwardUsername != "" && c.SecondaryForwardPassword != "" {
			users = append(users, map[string]interface{}{
				"user": c.SecondaryForwardUsername,
				"pass": c.SecondaryForwardPassword,
			})
		}
		
		outbound = map[string]interface{}{
			"protocol": "http",
			"settings": map[string]interface{}{
				"servers": []map[string]interface{}{
					{
						"address": c.SecondaryForwardAddress,
						"port":    c.SecondaryForwardPort,
					},
				},
			},
			"tag": tag,
		}
		
		// 如果有认证信息，添加到服务器配置
		if len(users) > 0 {
			outbound["settings"].(map[string]interface{})["servers"].([]map[string]interface{})[0]["users"] = users
		}
		
	default:
		return nil, ""
	}
	
	outboundJSON, _ := json.Marshal(outbound)
	return outboundJSON, tag
}

// GetSecondaryForwardRoutingRule 获取二次转发的路由规则
func GetSecondaryForwardRoutingRule(c *model.InboundConfig) (json_util.RawMessage, string) {
	if !c.SecondaryForwardEnable || c.SecondaryForwardProtocol == "" {
		return nil, ""
	}
	
	tag := fmt.Sprintf("%s-forward-%d", c.SecondaryForwardProtocol, c.Port)
	
	// 创建路由规则：将此入站的所有流量转发到对应的代理出站
	routingRule := map[string]interface{}{
		"type": "field",
		"inboundTag": []string{c.Tag},
		"outboundTag": tag,
	}
	
	routingRuleJSON, _ := json.Marshal(routingRule)
	return routingRuleJSON, tag
}

// HasSecondaryForward 检查是否有二次转发配置
func HasSecondaryForward(c *model.InboundConfig) bool {
	return c.SecondaryForwardEnable && c.SecondaryForwardProtocol != "" && 
	       c.SecondaryForwardAddress != "" && c.SecondaryForwardPort > 0
}
