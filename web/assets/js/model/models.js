class User {

    constructor() {
        this.username = "";
        this.password = "";
    }
}

class Msg {

    constructor(success, msg, obj) {
        this.success = false;
        this.msg = "";
        this.obj = null;

        if (success != null) {
            this.success = success;
        }
        if (msg != null) {
            this.msg = msg;
        }
        if (obj != null) {
            this.obj = obj;
        }
    }
}

class DBInbound {

    constructor(data) {
        this.id = 0;
        this.userId = 0;
        this.up = 0;
        this.down = 0;
        this.total = 0;
        this.remark = "";
        this.enable = true;
        this.expiryTime = 0;

        this.listen = "";
        this.port = 0;
        this.protocol = "";
        this.settings = "";
        this.streamSettings = "";
        this.tag = "";
        this.sniffing = "";

        // 二次转发配置
        this.secondaryForwardEnable = false;
        this.secondaryForwardProtocol = "none";
        this.secondaryForwardAddress = "";
        this.secondaryForwardPort = 0;
        this.secondaryForwardUsername = "";
        this.secondaryForwardPassword = "";

        if (data == null) {
            return;
        }
        ObjectUtil.cloneProps(this, data);
    }

    get totalGB() {
        return toFixed(this.total / ONE_GB, 2);
    }

    set totalGB(gb) {
        this.total = toFixed(gb * ONE_GB, 0);
    }

    get isVMess() {
        return this.protocol === Protocols.VMESS;
    }

    get isVLess() {
        return this.protocol === Protocols.VLESS;
    }

    get isTrojan() {
        return this.protocol === Protocols.TROJAN;
    }

    get isSS() {
        return this.protocol === Protocols.SHADOWSOCKS;
    }

    get isSocks() {
        return this.protocol === Protocols.SOCKS;
    }

    get isHTTP() {
        return this.protocol === Protocols.HTTP;
    }

    get address() {
        let address = location.hostname;
        if (!ObjectUtil.isEmpty(this.listen) && this.listen !== "0.0.0.0") {
            address = this.listen;
        }
        return address;
    }

    get _expiryTime() {
        if (this.expiryTime === 0) {
            return null;
        }
        return moment(this.expiryTime);
    }

    set _expiryTime(t) {
        if (t == null) {
            this.expiryTime = 0;
        } else {
            this.expiryTime = t.valueOf();
        }
    }

    get isExpiry() {
        return this.expiryTime < new Date().getTime();
    }

    // 检查是否启用了二次转发
    get hasSecondaryForward() {
        return this.secondaryForwardEnable && 
               this.secondaryForwardProtocol !== "none" && 
               this.secondaryForwardProtocol !== "";
    }

    // 获取二次转发服务器地址（带端口）
    get secondaryForwardServer() {
        if (!this.hasSecondaryForward) {
            return "";
        }
        return `${this.secondaryForwardAddress}:${this.secondaryForwardPort}`;
    }

    // 检查是否需要认证
    get secondaryForwardHasAuth() {
        return !ObjectUtil.isEmpty(this.secondaryForwardUsername) || 
               !ObjectUtil.isEmpty(this.secondaryForwardPassword);
    }

    toInbound() {
        let settings = {};
        if (!ObjectUtil.isEmpty(this.settings)) {
            settings = JSON.parse(this.settings);
        }

        let streamSettings = {};
        if (!ObjectUtil.isEmpty(this.streamSettings)) {
            streamSettings = JSON.parse(this.streamSettings);
        }

        let sniffing = {};
        if (!ObjectUtil.isEmpty(this.sniffing)) {
            sniffing = JSON.parse(this.sniffing);
        }
        
        const config = {
            port: this.port,
            listen: this.listen,
            protocol: this.protocol,
            settings: settings,
            streamSettings: streamSettings,
            tag: this.tag,
            sniffing: sniffing,
            // 添加二次转发配置
            secondaryForwardEnable: this.secondaryForwardEnable,
            secondaryForwardProtocol: this.secondaryForwardProtocol,
            secondaryForwardAddress: this.secondaryForwardAddress,
            secondaryForwardPort: this.secondaryForwardPort,
            secondaryForwardUsername: this.secondaryForwardUsername,
            secondaryForwardPassword: this.secondaryForwardPassword,
        };
        return Inbound.fromJson(config);
    }

    hasLink() {
        switch (this.protocol) {
            case Protocols.VMESS:
            case Protocols.VLESS:
            case Protocols.TROJAN:
            case Protocols.SHADOWSOCKS:
                return true;
            default:
                return false;
        }
    }

    genLink() {
        const inbound = this.toInbound();
        return inbound.genLink(this.address, this.remark);
    }

    // 验证二次转发配置
    validateSecondaryForward() {
        if (!this.secondaryForwardEnable) {
            return { valid: true, message: "" };
        }
        
        if (this.secondaryForwardProtocol === "none" || this.secondaryForwardProtocol === "") {
            return { valid: false, message: "启用二次转发时必须选择协议类型" };
        }
        
        if (ObjectUtil.isEmpty(this.secondaryForwardAddress)) {
            return { valid: false, message: "二次转发服务器地址不能为空" };
        }
        
        if (this.secondaryForwardPort <= 0 || this.secondaryForwardPort > 65535) {
            return { valid: false, message: "二次转发端口必须在1-65535之间" };
        }
        
        return { valid: true, message: "" };
    }
}

class AllSetting {

    constructor(data) {
        this.webListen = "";
        this.webPort = 54321;
        this.webCertFile = "";
        this.webKeyFile = "";
        this.webBasePath = "/";
        this.tgBotEnable = false;
        this.tgBotToken = "";
        this.tgBotChatId = 0;
        this.tgRunTime = "";
        this.xrayTemplateConfig = "";

        this.timeLocation = "Asia/Shanghai";

        if (data == null) {
            return
        }
        ObjectUtil.cloneProps(this, data);
    }

    equals(other) {
        return ObjectUtil.equals(this, other);
    }
}
