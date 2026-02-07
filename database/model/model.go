package model

import (
	"fmt"
	"x-ui/util/json_util"
	"x-ui/xray"
)

type Protocol string

const (
	VMess       Protocol = "vmess"
	VLESS       Protocol = "vless"
	Dokodemo    Protocol = "Dokodemo-door"
	Http        Protocol = "http"
	Trojan      Protocol = "trojan"
	Shadowsocks Protocol = "shadowsocks"
)

// 二次转发协议类型常量
const (
	SecondaryForwardNone  = "none"
	SecondaryForwardSOCKS = "socks"
	SecondaryForwardHTTP  = "http"
	SecondaryForwardHTTPS = "https"
)

type User struct {
	Id       int    `json:"id" gorm:"primaryKey;autoIncrement"`
	Username string `json:"username"`
	Password string `json:"password"`
}

type Inbound struct {
	Id         int    `json:"id" form:"id" gorm:"primaryKey;autoIncrement"`
	UserId     int    `json:"-"`
	Up         int64  `json:"up" form:"up"`
	Down       int64  `json:"down" form:"down"`
	Total      int64  `json:"total" form:"total"`
	Remark     string `json:"remark" form:"remark"`
	Enable     bool   `json:"enable" form:"enable"`
	ExpiryTime int64  `json:"expiryTime" form:"expiryTime"`

	// config part
	Listen         string   `json:"listen" form:"listen"`
	Port           int      `json:"port" form:"port" gorm:"unique"`
	Protocol       Protocol `json:"protocol" form:"protocol"`
	Settings       string   `json:"settings" form:"settings"`
	StreamSettings string   `json:"streamSettings" form:"streamSettings"`
	Tag            string   `json:"tag" form:"tag" gorm:"unique"`
	Sniffing       string   `json:"sniffing" form:"sniffing"`
	
	// ===== 添加二次转发配置字段 =====
	SecondaryForwardEnable   bool   `json:"secondaryForwardEnable" form:"secondaryForwardEnable" gorm:"default:false"`
	SecondaryForwardProtocol string `json:"secondaryForwardProtocol" form:"secondaryForwardProtocol" gorm:"default:'none'"`
	SecondaryForwardAddress  string `json:"secondaryForwardAddress" form:"secondaryForwardAddress" gorm:"default:''"`
	SecondaryForwardPort     int    `json:"secondaryForwardPort" form:"secondaryForwardPort" gorm:"default:0"`
	SecondaryForwardUsername string `json:"secondaryForwardUsername" form:"secondaryForwardUsername" gorm:"default:''"`
	SecondaryForwardPassword string `json:"secondaryForwardPassword" form:"secondaryForwardPassword" gorm:"default:''"`
}

func (i *Inbound) GenXrayInboundConfig() *xray.InboundConfig {
	listen := i.Listen
	if listen != "" {
		listen = fmt.Sprintf("\"%v\"", listen)
	}
	
	config := &xray.InboundConfig{
		Listen:         json_util.RawMessage(listen),
		Port:           i.Port,
		Protocol:       string(i.Protocol),
		Settings:       json_util.RawMessage(i.Settings),
		StreamSettings: json_util.RawMessage(i.StreamSettings),
		Tag:            i.Tag,
		Sniffing:       json_util.RawMessage(i.Sniffing),
		
		// 传递二次转发配置
		SecondaryForwardEnable:   i.SecondaryForwardEnable,
		SecondaryForwardProtocol: i.SecondaryForwardProtocol,
		SecondaryForwardAddress:  i.SecondaryForwardAddress,
		SecondaryForwardPort:     i.SecondaryForwardPort,
		SecondaryForwardUsername: i.SecondaryForwardUsername,
		SecondaryForwardPassword: i.SecondaryForwardPassword,
	}
	
	return config
}

type Setting struct {
	Id    int    `json:"id" form:"id" gorm:"primaryKey;autoIncrement"`
	Key   string `json:"key" form:"key"`
	Value string `json:"value" form:"value"`
}
