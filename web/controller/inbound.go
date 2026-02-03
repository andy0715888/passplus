package controller

import (
	"fmt"
	"github.com/gin-gonic/gin"
	"strconv"
	"x-ui/database/model"
	"x-ui/logger"
	"x-ui/web/global"
	"x-ui/web/service"
	"x-ui/web/session"
)

type InboundController struct {
	inboundService service.InboundService
	xrayService    service.XrayService
}

func NewInboundController(g *gin.RouterGroup) *InboundController {
	a := &InboundController{}
	a.initRouter(g)
	a.startTask()
	return a
}

func (a *InboundController) initRouter(g *gin.RouterGroup) {
	g = g.Group("/inbound")

	g.POST("/list", a.getInbounds)
	g.POST("/add", a.addInbound)
	g.POST("/del/:id", a.delInbound)
	g.POST("/update/:id", a.updateInbound)
}

func (a *InboundController) startTask() {
	webServer := global.GetWebServer()
	c := webServer.GetCron()
	c.AddFunc("@every 10s", func() {
		if a.xrayService.IsNeedRestartAndSetFalse() {
			err := a.xrayService.RestartXray(false)
			if err != nil {
				logger.Error("restart xray failed:", err)
			}
		}
	})
}

func (a *InboundController) getInbounds(c *gin.Context) {
	user := session.GetLoginUser(c)
	inbounds, err := a.inboundService.GetInbounds(user.Id)
	if err != nil {
		jsonMsg(c, "获取", err)
		return
	}
	jsonObj(c, inbounds, nil)
}

func (a *InboundController) addInbound(c *gin.Context) {
	inbound := &model.Inbound{}
	err := c.ShouldBind(inbound)
	if err != nil {
		jsonMsg(c, "添加", err)
		return
	}
	
	// 验证二次转发配置
	if err := a.validateSecondaryForward(inbound); err != nil {
		jsonMsg(c, "添加", err)
		return
	}
	
	user := session.GetLoginUser(c)
	inbound.UserId = user.Id
	inbound.Enable = true
	inbound.Tag = fmt.Sprintf("inbound-%v", inbound.Port)
	
	// 设置二次转发默认值
	a.setSecondaryForwardDefaults(inbound)
	
	err = a.inboundService.AddInbound(inbound)
	jsonMsg(c, "添加", err)
	if err == nil {
		a.xrayService.SetToNeedRestart()
	}
}

func (a *InboundController) delInbound(c *gin.Context) {
	id, err := strconv.Atoi(c.Param("id"))
	if err != nil {
		jsonMsg(c, "删除", err)
		return
	}
	err = a.inboundService.DelInbound(id)
	jsonMsg(c, "删除", err)
	if err == nil {
		a.xrayService.SetToNeedRestart()
	}
}

func (a *InboundController) updateInbound(c *gin.Context) {
	id, err := strconv.Atoi(c.Param("id"))
	if err != nil {
		jsonMsg(c, "修改", err)
		return
	}
	inbound := &model.Inbound{
		Id: id,
	}
	err = c.ShouldBind(inbound)
	if err != nil {
		jsonMsg(c, "修改", err)
		return
	}
	
	// 验证二次转发配置
	if err := a.validateSecondaryForward(inbound); err != nil {
		jsonMsg(c, "修改", err)
		return
	}
	
	// 设置二次转发默认值
	a.setSecondaryForwardDefaults(inbound)
	
	err = a.inboundService.UpdateInbound(inbound)
	jsonMsg(c, "修改", err)
	if err == nil {
		a.xrayService.SetToNeedRestart()
	}
}

// validateSecondaryForward 验证二次转发配置
func (a *InboundController) validateSecondaryForward(inbound *model.Inbound) error {
	if !inbound.SecondaryForwardEnable {
		return nil
	}
	
	if inbound.SecondaryForwardProtocol == model.SecondaryForwardNone {
		return fmt.Errorf("启用二次转发时必须选择协议类型")
	}
	
	if inbound.SecondaryForwardAddress == "" {
		return fmt.Errorf("二次转发服务器地址不能为空")
	}
	
	if inbound.SecondaryForwardPort <= 0 || inbound.SecondaryForwardPort > 65535 {
		return fmt.Errorf("二次转发端口必须在1-65535之间")
	}
	
	// 如果选择了SOCKS或HTTP协议，确保地址和端口有效
	if inbound.SecondaryForwardProtocol == model.SecondaryForwardSOCKS || 
		inbound.SecondaryForwardProtocol == model.SecondaryForwardHTTP {
		if inbound.SecondaryForwardAddress == "" {
			return fmt.Errorf("%s服务器地址不能为空", inbound.SecondaryForwardProtocol)
		}
		if inbound.SecondaryForwardPort == 0 {
			return fmt.Errorf("%s服务器端口不能为0", inbound.SecondaryForwardProtocol)
		}
	}
	
	return nil
}

// setSecondaryForwardDefaults 设置二次转发默认值
func (a *InboundController) setSecondaryForwardDefaults(inbound *model.Inbound) {
	if !inbound.SecondaryForwardEnable {
		// 如果未启用二次转发，重置相关字段
		inbound.SecondaryForwardProtocol = model.SecondaryForwardNone
		inbound.SecondaryForwardAddress = ""
		inbound.SecondaryForwardPort = 0
		inbound.SecondaryForwardUsername = ""
		inbound.SecondaryForwardPassword = ""
	} else if inbound.SecondaryForwardProtocol == model.SecondaryForwardNone {
		// 如果协议为none，也视为未启用
		inbound.SecondaryForwardEnable = false
		inbound.SecondaryForwardAddress = ""
		inbound.SecondaryForwardPort = 0
		inbound.SecondaryForwardUsername = ""
		inbound.SecondaryForwardPassword = ""
	}
}
