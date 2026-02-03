package xray

import (
	"bytes"
	"encoding/json"
	"x-ui/database/model"
	"x-ui/util/json_util"
)

type InboundConfig struct {
	Listen         json_util.RawMessage `json:"listen"` // listen 不能为空字符串
	Port           int                  `json:"port"`
	Protocol       string               `json:"protocol"`
	Settings       json_util.RawMessage `json:"settings"`
	StreamSettings json_util.RawMessage `json:"streamSettings"`
	Tag            string               `json:"tag"`
	Sniffing       json_util.RawMessage `json:"sniffing"`
	
	// 二次转发配置
	SecondaryForwardEnable   bool   `json:"secondaryForwardEnable"`
	SecondaryForwardProtocol string `json:"secondaryForwardProtocol"`
	SecondaryForwardAddress  string `json:"secondaryForwardAddress"`
	SecondaryForwardPort     int    `json:"secondaryForwardPort"`
	SecondaryForwardUsername string `json:"secondaryForwardUsername"`
	SecondaryForwardPassword string `json:"secondaryForwardPassword"`
}

func (c *InboundConfig) Equals(other *InboundConfig) bool {
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
func (c *InboundConfig) ApplySecondaryForward() {
	if !c.SecondaryForwardEnable || c.SecondaryForwardProtocol == "none" {
		return
	}
	
	// 根据协议类型应用二次转发配置
	switch c.SecondaryForwardProtocol {
	case string(model.SecondaryForwardSOCKS):
		c.applySocksForward()
	case string(model.SecondaryForwardHTTP):
		c.applyHTTPForward()
	}
}

// applySocksForward 应用SOCKS二次转发
func (c *InboundConfig) applySocksForward() {
	// 解析现有的settings
	var settings map[string]interface{}
	if len(c.Settings) > 0 {
		json.Unmarshal(c.Settings, &settings)
	} else {
		settings = make(map[string]interface{})
	}
	
	// 添加SOCKS代理设置
	proxySettings := map[string]interface{}{
		"proxySettings": map[string]interface{}{
			"tag": "socks-forward",
			"transportLayer": false,
		},
	}
	
	// 合并设置
	for k, v := range proxySettings {
		settings[k] = v
	}
	
	// 更新settings
	updatedSettings, _ := json.Marshal(settings)
	c.Settings = updatedSettings
	
	// 创建SOCKS出站配置（需要在outbounds中添加）
	// 注意：这里只是标记，实际的出站配置需要在其他地方处理
}

// applyHTTPForward 应用HTTP二次转发
func (c *InboundConfig) applyHTTPForward() {
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
			"tag": "http-forward",
			"transportLayer": false,
		},
	}
	
	// 合并设置
	for k, v := range proxySettings {
		settings[k] = v
	}
	
	// 更新settings
	updatedSettings, _ := json.Marshal(settings)
	c.Settings = updatedSettings
	
	// 创建HTTP出站配置（需要在outbounds中添加）
	// 注意：这里只是标记，实际的出站配置需要在其他地方处理
}

// GetSecondaryForwardOutbound 获取二次转发出站配置
func (c *InboundConfig) GetSecondaryForwardOutbound() json_util.RawMessage {
	if !c.SecondaryForwardEnable || c.SecondaryForwardProtocol == "none" {
		return nil
	}
	
	var outbound map[string]interface{}
	
	switch c.SecondaryForwardProtocol {
	case string(model.SecondaryForwardSOCKS):
		outbound = map[string]interface{}{
			"protocol": "socks",
			"settings": map[string]interface{}{
				"servers": []map[string]interface{}{
					{
						"address": c.SecondaryForwardAddress,
						"port":    c.SecondaryForwardPort,
						"users": []map[string]interface{}{
							{
								"user": c.SecondaryForwardUsername,
								"pass": c.SecondaryForwardPassword,
							},
						},
					},
				},
			},
			"tag": "socks-forward-outbound",
		}
	case string(model.SecondaryForwardHTTP):
		outbound = map[string]interface{}{
			"protocol": "http",
			"settings": map[string]interface{}{
				"servers": []map[string]interface{}{
					{
						"address": c.SecondaryForwardAddress,
						"port":    c.SecondaryForwardPort,
						"users": []map[string]interface{}{
							{
								"user": c.SecondaryForwardUsername,
								"pass": c.SecondaryForwardPassword,
							},
						},
					},
				},
			},
			"tag": "http-forward-outbound",
		}
	default:
		return nil
	}
	
	outboundJSON, _ := json.Marshal(outbound)
	return outboundJSON
}
