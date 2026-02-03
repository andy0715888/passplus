package service

import (
	"fmt"
	"time"
	"x-ui/database"
	"x-ui/database/model"
	"x-ui/util/common"
	"x-ui/xray"

	"gorm.io/gorm"
)

type InboundService struct {
}

func (s *InboundService) GetInbounds(userId int) ([]*model.Inbound, error) {
	db := database.GetDB()
	var inbounds []*model.Inbound
	err := db.Model(model.Inbound{}).Where("user_id = ?", userId).Find(&inbounds).Error
	if err != nil && err != gorm.ErrRecordNotFound {
		return nil, err
	}
	return inbounds, nil
}

func (s *InboundService) GetAllInbounds() ([]*model.Inbound, error) {
	db := database.GetDB()
	var inbounds []*model.Inbound
	err := db.Model(model.Inbound{}).Find(&inbounds).Error
	if err != nil && err != gorm.ErrRecordNotFound {
		return nil, err
	}
	return inbounds, nil
}

func (s *InboundService) checkPortExist(port int, ignoreId int) (bool, error) {
	db := database.GetDB()
	db = db.Model(model.Inbound{}).Where("port = ?", port)
	if ignoreId > 0 {
		db = db.Where("id != ?", ignoreId)
	}
	var count int64
	err := db.Count(&count).Error
	if err != nil {
		return false, err
	}
	return count > 0, nil
}

func (s *InboundService) AddInbound(inbound *model.Inbound) error {
	// 验证端口是否存在
	exist, err := s.checkPortExist(inbound.Port, 0)
	if err != nil {
		return err
	}
	if exist {
		return common.NewError("端口已存在:", inbound.Port)
	}
	
	// 验证二次转发配置
	if err := s.validateSecondaryForward(inbound); err != nil {
		return err
	}
	
	// 设置二次转发默认值
	s.setSecondaryForwardDefaults(inbound)
	
	// 设置tag
	inbound.Tag = fmt.Sprintf("inbound-%v", inbound.Port)
	
	db := database.GetDB()
	return db.Save(inbound).Error
}

func (s *InboundService) AddInbounds(inbounds []*model.Inbound) error {
	for _, inbound := range inbounds {
		exist, err := s.checkPortExist(inbound.Port, 0)
		if err != nil {
			return err
		}
		if exist {
			return common.NewError("端口已存在:", inbound.Port)
		}
		
		// 验证二次转发配置
		if err := s.validateSecondaryForward(inbound); err != nil {
			return err
		}
		
		// 设置二次转发默认值
		s.setSecondaryForwardDefaults(inbound)
		
		// 设置tag
		inbound.Tag = fmt.Sprintf("inbound-%v", inbound.Port)
	}

	db := database.GetDB()
	tx := db.Begin()
	var err error
	defer func() {
		if err == nil {
			tx.Commit()
		} else {
			tx.Rollback()
		}
	}()

	for _, inbound := range inbounds {
		err = tx.Save(inbound).Error
		if err != nil {
			return err
		}
	}

	return nil
}

func (s *InboundService) DelInbound(id int) error {
	db := database.GetDB()
	return db.Delete(model.Inbound{}, id).Error
}

func (s *InboundService) GetInbound(id int) (*model.Inbound, error) {
	db := database.GetDB()
	inbound := &model.Inbound{}
	err := db.Model(model.Inbound{}).First(inbound, id).Error
	if err != nil {
		return nil, err
	}
	return inbound, nil
}

func (s *InboundService) UpdateInbound(inbound *model.Inbound) error {
	// 验证端口是否存在
	exist, err := s.checkPortExist(inbound.Port, inbound.Id)
	if err != nil {
		return err
	}
	if exist {
		return common.NewError("端口已存在:", inbound.Port)
	}

	// 验证二次转发配置
	if err := s.validateSecondaryForward(inbound); err != nil {
		return err
	}
	
	// 设置二次转发默认值
	s.setSecondaryForwardDefaults(inbound)

	oldInbound, err := s.GetInbound(inbound.Id)
	if err != nil {
		return err
	}
	oldInbound.Up = inbound.Up
	oldInbound.Down = inbound.Down
	oldInbound.Total = inbound.Total
	oldInbound.Remark = inbound.Remark
	oldInbound.Enable = inbound.Enable
	oldInbound.ExpiryTime = inbound.ExpiryTime
	oldInbound.Listen = inbound.Listen
	oldInbound.Port = inbound.Port
	oldInbound.Protocol = inbound.Protocol
	oldInbound.Settings = inbound.Settings
	oldInbound.StreamSettings = inbound.StreamSettings
	oldInbound.Sniffing = inbound.Sniffing
	
	// 更新二次转发配置
	oldInbound.SecondaryForwardEnable = inbound.SecondaryForwardEnable
	oldInbound.SecondaryForwardProtocol = inbound.SecondaryForwardProtocol
	oldInbound.SecondaryForwardAddress = inbound.SecondaryForwardAddress
	oldInbound.SecondaryForwardPort = inbound.SecondaryForwardPort
	oldInbound.SecondaryForwardUsername = inbound.SecondaryForwardUsername
	oldInbound.SecondaryForwardPassword = inbound.SecondaryForwardPassword
	
	oldInbound.Tag = fmt.Sprintf("inbound-%v", inbound.Port)

	db := database.GetDB()
	return db.Save(oldInbound).Error
}

func (s *InboundService) AddTraffic(traffics []*xray.Traffic) (err error) {
	if len(traffics) == 0 {
		return nil
	}
	db := database.GetDB()
	db = db.Model(model.Inbound{})
	tx := db.Begin()
	defer func() {
		if err != nil {
			tx.Rollback()
		} else {
			tx.Commit()
		}
	}()
	for _, traffic := range traffics {
		if traffic.IsInbound {
			err = tx.Where("tag = ?", traffic.Tag).
				UpdateColumn("up", gorm.Expr("up + ?", traffic.Up)).
				UpdateColumn("down", gorm.Expr("down + ?", traffic.Down)).
				Error
			if err != nil {
				return
			}
		}
	}
	return
}

func (s *InboundService) DisableInvalidInbounds() (int64, error) {
	db := database.GetDB()
	now := time.Now().Unix() * 1000
	result := db.Model(model.Inbound{}).
		Where("((total > 0 and up + down >= total) or (expiry_time > 0 and expiry_time <= ?)) and enable = ?", now, true).
		Update("enable", false)
	err := result.Error
	count := result.RowsAffected
	return count, err
}

// validateSecondaryForward 验证二次转发配置
func (s *InboundService) validateSecondaryForward(inbound *model.Inbound) error {
	if !inbound.SecondaryForwardEnable {
		return nil
	}
	
	if inbound.SecondaryForwardProtocol == model.SecondaryForwardNone {
		return common.NewError("启用二次转发时必须选择协议类型")
	}
	
	if inbound.SecondaryForwardAddress == "" {
		return common.NewError("二次转发服务器地址不能为空")
	}
	
	if inbound.SecondaryForwardPort <= 0 || inbound.SecondaryForwardPort > 65535 {
		return common.NewError("二次转发端口必须在1-65535之间")
	}
	
	// 如果选择了SOCKS或HTTP协议，确保地址和端口有效
	if inbound.SecondaryForwardProtocol == model.SecondaryForwardSOCKS || 
		inbound.SecondaryForwardProtocol == model.SecondaryForwardHTTP {
		if inbound.SecondaryForwardAddress == "" {
			return common.NewError("%s服务器地址不能为空", inbound.SecondaryForwardProtocol)
		}
		if inbound.SecondaryForwardPort == 0 {
			return common.NewError("%s服务器端口不能为0", inbound.SecondaryForwardProtocol)
		}
	}
	
	return nil
}

// setSecondaryForwardDefaults 设置二次转发默认值
func (s *InboundService) setSecondaryForwardDefaults(inbound *model.Inbound) {
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

// GetInboundsWithSecondaryForward 获取启用二次转发的入站配置
func (s *InboundService) GetInboundsWithSecondaryForward() ([]*model.Inbound, error) {
	db := database.GetDB()
	var inbounds []*model.Inbound
	err := db.Model(model.Inbound{}).
		Where("secondary_forward_enable = ? AND secondary_forward_protocol != ?", 
			true, model.SecondaryForwardNone).
		Find(&inbounds).Error
	if err != nil && err != gorm.ErrRecordNotFound {
		return nil, err
	}
	return inbounds, nil
}
