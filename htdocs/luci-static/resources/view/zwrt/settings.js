'use strict';
'require form';

return L.view.extend({
	render: function() {
		var m, s, o;

		m = new form.Map('zwrt', _('ZWRT主题设置'), _('ZWRT 主题外观设置'));

		s = m.section(form.NamedSection, 'basic', 'basic', _('基本设置'));
		s.addremove = false;

		o = s.option(form.ListValue, 'mode', _('主题模式'));
		o.value('light', _('浅色'));
		o.value('dark', _('深色'));
		o.value('auto', _('自动'));
		o.default = 'light';

		o = s.option(form.Flag, 'bkuse', _('启用背景壁纸'));
		o.default = '1';

		o = s.option(form.ListValue, 'background', _('背景来源'));
		o.value('0', _('内置默认'));
		o.value('1', _('iciba'));
		o.value('2', _('Unsplash'));
		o.value('3', _('Bing'));
		o.value('4', _('小鸟壁纸 (birdpaper)'));
		o.value('5', _('Wallhaven'));
		o.default = '0';

		o = s.option(form.Value, 'primary_rgbs', _('主色 RGB（亮）'));
		o.placeholder = '28,66,188';

		o = s.option(form.Value, 'primary_rgbm', _('主色 RGB（暗）'));
		o.placeholder = '20,109,179';

		o = s.option(form.Value, 'primary_opacity', _('主色透明度 (0-100)'));
		o.placeholder = '0';

		o = s.option(form.Flag, 'setbar', _('显示侧边栏'));
		o.default = '1';

		o = s.option(form.Flag, 'dayword', _('每日一言'));
		o.default = '0';

		o = s.option(form.ListValue, 'gohome', _('状态快捷入口（房子图标）'), _('右下角房子图标跳转的状态页面'));
		o.value('overview', _('概览 Overview'));
		o.value('routes', _('路由 Routing'));
		o.value('firewall', _('防火墙 Firewall'));
		o.value('logs', _('系统日志 Logs'));
		o.value('processes', _('进程 Processes'));
		o.value('realtime', _('实时流量 Realtime'));
		o.default = 'overview';
		o.rmempty = false;

		o = s.option(form.ListValue, 'gouser', _('系统快捷入口（扳手图标）'), _('右下角扳手图标跳转的系统页面'));
		o.value('system', _('系统 System'));
		o.value('admin', _('管理权 Administration'));
		o.value('filemanager', _('文件管理 File Manager'));
		o.value('ttyd', _('终端 Terminal'));
		o.value('poweroffdevice', _('关机 PowerOff'));
		o.default = 'system';
		o.rmempty = false;

		o = s.option(form.ListValue, 'gossr', _('科学上网快捷入口（纸飞机图标）'), _('右下角纸飞机图标跳转的代理应用，未安装时选择“不显示”'));
		o.value('', _('不显示'));
		o.value('openclash', _('OpenClash'));
		o.value('homeproxy', _('HomeProxy'));
		o.value('nikki', _('Nikki'));
		o.value('passwall', _('PassWall'));
		o.value('passwall2', _('PassWall2'));
		o.value('shadowsocksr', _('SSR'));
		o.value('bypass', _('Bypass'));
		o.value('mosdns', _('MosDNS'));
		o.value('smartdns', _('SmartDNS'));
		o.value('AdGuardHome', _('AdGuard Home'));
		o.default = '';
		o.rmempty = true;

		o = s.option(form.Value, 'font_d', _('大号字体'));
		o.placeholder = '1.1rem';

		o = s.option(form.Value, 'font_z', _('中号字体'));
		o.placeholder = '0.92rem';

		o = s.option(form.Value, 'font_x', _('小号字体'));
		o.placeholder = '0.875rem';

		return m.render();
	}
});
