package database

import (
	"gorm.io/driver/sqlite"
	"gorm.io/gorm"
	"gorm.io/gorm/logger"
	"io/fs"
	"os"
	"path"
	"x-ui/config"
	"x-ui/database/model"
)

var db *gorm.DB

func initUser() error {
	err := db.AutoMigrate(&model.User{})
	if err != nil {
		return err
	}
	var count int64
	err = db.Model(&model.User{}).Count(&count).Error
	if err != nil {
		return err
	}
	if count == 0 {
		user := &model.User{
			Username: "admin",
			Password: "admin",
		}
		return db.Create(user).Error
	}
	return nil
}

func initInbound() error {
	// 首先自动迁移
	err := db.AutoMigrate(&model.Inbound{})
	if err != nil {
		return err
	}
	
	// 添加二次转发字段（如果不存在）
	// 使用 IF NOT EXISTS 避免重复添加
	err = db.Exec(`
		ALTER TABLE inbounds 
		ADD COLUMN IF NOT EXISTS secondary_forward_enable BOOLEAN DEFAULT FALSE,
		ADD COLUMN IF NOT EXISTS secondary_forward_protocol VARCHAR(20) DEFAULT 'none',
		ADD COLUMN IF NOT EXISTS secondary_forward_address VARCHAR(255) DEFAULT '',
		ADD COLUMN IF NOT EXISTS secondary_forward_port INTEGER DEFAULT 0,
		ADD COLUMN IF NOT EXISTS secondary_forward_username VARCHAR(255) DEFAULT '',
		ADD COLUMN IF NOT EXISTS secondary_forward_password VARCHAR(255) DEFAULT '';
	`).Error
	
	return err
}

func initSetting() error {
	return db.AutoMigrate(&model.Setting{})
}

func InitDB(dbPath string) error {
	dir := path.Dir(dbPath)
	err := os.MkdirAll(dir, fs.ModeDir)
	if err != nil {
		return err
	}

	var gormLogger logger.Interface

	if config.IsDebug() {
		gormLogger = logger.Default
	} else {
		gormLogger = logger.Discard
	}

	c := &gorm.Config{
		Logger: gormLogger,
	}
	db, err = gorm.Open(sqlite.Open(dbPath), c)
	if err != nil {
		return err
	}

	err = initUser()
	if err != nil {
		return err
	}
	err = initInbound()
	if err != nil {
		return err
	}
	err = initSetting()
	if err != nil {
		return err
	}

	return nil
}

func GetDB() *gorm.DB {
	return db
}

func IsNotFound(err error) bool {
	return err == gorm.ErrRecordNotFound
}
