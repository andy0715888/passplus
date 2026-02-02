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

type User struct {
	Id       int    `json:"id" gorm:"primaryKey;autoIncrement"`
	Username string `json:"username"`
	Password string `json:"password"`
}

type SecondaryForwardProtocol string

const (
	SecondaryForwardNone   SecondaryForwardProtocol = "none"
	SecondaryForwardSOCKS  SecondaryForwardProtocol = "socks"
	SecondaryForwardHTTP   SecondaryForwardProtocol = "http"
)

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

	// 二次转发配置
	SecondaryForwardEnable   bool                      `json:"secondaryForwardEnable" form:"secondaryForwardEnable" gorm:"default:false"`
	SecondaryForwardProtocol SecondaryForwardProtocol `json:"secondaryForwardProtocol" form:"secondaryForwardProtocol" gorm:"default:'none'"`
	SecondaryForwardAddress  string                    `json:"secondaryForwardAddress" form:"secondaryForwardAddress"`
	SecondaryForwardPort     int                       `json:"secondaryForwardPort" form:"secondaryForwardPort" gorm:"default:0"`
	SecondaryForwardUsername string                    `json:"secondaryForwardUsername" form:"secondaryForwardUsername"`
	SecondaryForwardPassword string                    `json:"secondaryForwardPassword" form:"secondaryForwardPassword"`
}

func (i *Inbound) GenXrayInboundConfig() *xray.InboundConfig {
	listen := i.Listen
	if listen != "" {
		listen = fmt.Sprintf("\"%v\"", listen)
	}
	return &xray.InboundConfig{
		Listen:         json_util.RawMessage(listen),
		Port:           i.Port,
		Protocol:       string(i.Protocol),
		Settings:       json_util.RawMessage(i.Settings),
		StreamSettings: json_util.RawMessage(i.StreamSettings),
		Tag:            i.Tag,
		Sniffing:       json_util.RawMessage(i.Sniffing),
	}
}

type Setting struct {
	Id    int    `json:"id" form:"id" gorm:"primaryKey;autoIncrement"`
	Key   string `json:"key" form:"key"`
	Value string `json:"value" form:"value"`
}
