# ===== text screen and tracking functions for version 1.9 with OSG =====
# ===== for Danube Class Runabout version 41.6  =====

var sin = func(a) { math.sin(a * math.pi / 180.0) }	# degrees
var cos = func(a) { math.cos(a * math.pi / 180.0) }
var asin = func(y) { math.atan2(y, math.sqrt(1-y*y)) }	# radians
var ERAD = 6378138.12; 		# Earth radius (m)
var m_2_conv = [0.000621371192, 0.001];
var m_conv_units = [" MI"," KM"];
var m_conv_format = [" %5.2f "," %4.3f "];
var ft_2_conv = [1.0, 0.3048];
var ft_conv_units = [" FT"," M"];
var ft_conv_format = [" %7.0f "," %8.1f "];

var normbearing = func (a,c) {
	var h = a - c;
	while (h >= 180)
		h -= 360;
	while (h < -180)
		h += 360;
	return h;
}

var normheading = func (a) {
	while (a >= 360)
		a -= 360;
	while (a < 0)
		a += 360;
	return a;
}

var bearing_to = func (bearing) {
	var normalized = normheading(bearing);
	return ((normalized > 90 and normalized < 270) ? 0 : 1);
}

var tracking_on = 0;
var refresh_2L = 0.2;
var a_mode = 0;
var c_view = 0;


# ======== nearest airport updated every 5 sec. =====================
var ap1_bearing_Node = props.globals.getNode("instrumentation/tracking/ap1-bearing-deg", 1);
var ap1_callsign_Node = props.globals.getNode("instrumentation/tracking/ap1-callsign", 1);
var ap1_dist_Node = props.globals.getNode("instrumentation/tracking/ap1-distance-m", 1);
var ap1_elev_Node = props.globals.getNode("instrumentation/tracking/ap1-elevation-deg", 1);
#var ap1_heading_offset_Node = props.globals.getNode("instrumentation/tracking/ap1-heading-offset", 1);
var ap1_heading_Node = props.globals.getNode("instrumentation/tracking/ap1-heading-deg", 1);
var ap1_name_Node = props.globals.getNode("instrumentation/tracking/ap1-name", 1);
var ap1_lat_Node = props.globals.getNode("instrumentation/tracking/ap1-lat", 1);
var ap1_lon_Node = props.globals.getNode("instrumentation/tracking/ap1-lon", 1);
var ap1_range_Node = props.globals.getNode("instrumentation/tracking/ap1-range", 1);
var apt_loop_id = 0;
var apt_loop = func (id) {
	id == apt_loop_id or return;
	var a = airportinfo();
	if (apt == nil or apt.id != a.id) {
		apt = a;
		var is_heliport = 1;
		foreach (var rwy; keys(apt.runways)) {
			if (rwy[0] != `H`) {
				is_heliport = 0;
			}
		}
		if (is_heliport) {
			ap1_callsign_Node.setValue(apt.id ~ "  HELIPORT");
		} else {
			ap1_callsign_Node.setValue(apt.id);
		}
		ap1_name_Node.setValue(apt.name);
		ap1_lat_Node.setValue(apt.lat);
		ap1_lon_Node.setValue(apt.lon);
		ap1_elev_Node.setValue(apt.elevation);
	}
	settimer(func { apt_loop(id) }, 5);
}

# ======== update tracking for nearest airport every 0.25 sec =======
var apt_update_id = 0;
var apt_update = func (id) {
	id == apt_update_id or return;
	var c_lat = getprop("position/latitude-deg");
	var c_lon = getprop("position/longitude-deg");
	var c_head_deg = getprop("orientation/heading-deg");
	if (apt != nil) {
		var avglat = (c_lat + apt.lat) / 2;
		var y = apt.lat - c_lat;
		var x_grid = apt.lon - c_lon;
		# international date line is not observed in airportinfo
		var x = x_grid * cos(avglat);
		var xy_hyp = math.sqrt((x * x) + (y * y));
		var head = (xy_hyp == 0 ? 0 : asin(x / xy_hyp)) * 180 / math.pi;
		head = (c_lat > apt.lat ? normheading(180 - head) : normheading(head));
		var bearing = normbearing(head, c_head_deg);
		ap1_heading_Node.setValue(head);
		ap1_bearing_Node.setValue(bearing);
		setprop("instrumentation/tracking/ap1-to", bearing_to(bearing));
		var range = walk.distFromCraft(apt.lat, apt.lon);
		ap1_dist_Node.setValue(range);
		var c_alt = getprop("position/altitude-ft");
		var e_m = apt.elevation - (c_alt * 0.3048);
		var xy_hyp = math.sqrt((e_m * e_m) + (range * range));
		var ze = (xy_hyp == 0 ? 0 : asin(e_m / xy_hyp)) * 180 / math.pi;
		ap1_elev_Node.setValue(ze);
		range = range * m_2_conv[a_mode];
		var txt18 = sprintf("%7.2f",range) ~ m_conv_units[a_mode];
		ap1_range_Node.setValue(txt18);
	}
	settimer(func { apt_update(id) }, 0.25);
}

# ======== nearest aircraft ============================
var cleanup_2L = func {
	var ai_s = getprop("instrumentation/tracking/ai-size");
	var mp_s = getprop("instrumentation/tracking/mp-size");
	var s = (ai_s > -1 ? ai_s : 0) + (mp_s > -1 ? mp_s : 0);
	for (var i = s ; i <= 13 ; i += 1) {
		setprop("instrumentation/display-screens/t2L-" ~ (i+3) ~ "a", " ");
		setprop("instrumentation/display-screens/t2L-" ~ (i+3) ~ "b", " ");
		setprop("instrumentation/display-screens/t2L-" ~ (i+3) ~ "c", " ");
	}
}

var ai_i = -1;
var mp_i = -1;
var ac_update = func {
	var ac = props.globals.getNode("ai/models").getChildren("aircraft");
	var mp = props.globals.getNode("ai/models").getChildren("multiplayer");
	if (ac != nil) {
		var c_lat = getprop("position/latitude-deg");
		var c_lon = getprop("position/longitude-deg");
		var c_alt = getprop("position/altitude-ft");
		var c_head_deg = getprop("orientation/heading-deg");
		var ac_list = [];
		var s = size(ac);
		var ac_closest = -1;
		var ac_closest_distance = 999999;
		var ac_i = 0;
		for (var i = 0 ; i < s ; i += 1) {
			if(ac[i].getNode("callsign") != nil and ac[i].getNode("valid").getValue()) {
				var b = ac[i].getNode("position");
				var alat = b.getNode("latitude-deg").getValue();
				var alon = b.getNode("longitude-deg").getValue();
				var avglat = (c_lat + alat) / 2;
				var y = alat - c_lat;
				var x_grid = alon - c_lon;
				# don't waste resources checking for longitude -180 in ai_aircraft
#				if (avglat < 90 and avglat > -90) {
					var x = x_grid * cos(avglat);
#				} else {
#					print ("Error detected in aircraft section, line 150  avglat= ",avglat);
#					var x = x_grid * cos(c_lat);
#				}
				var ah1 = sin(y * 0.5);
				var ah2 = sin(x * 0.5);
				var adist_m = 2.0 * ERAD * asin(math.sqrt(ah1 * ah1 + cos(alat) * cos(c_lat) * ah2 * ah2));
				var xy_hyp = math.sqrt((x * x) + (y * y));
				var head = (xy_hyp == 0 ? 0 : asin(x / xy_hyp)) * 180 / math.pi;
				head = (c_lat > alat ? normheading(180 - head) : normheading(head));
				var bearing = normbearing(head, c_head_deg);
				append(ac_list, { type: 1, callsign:ac[i].getNode("callsign").getValue(), index:i, dist_m:adist_m, alt_ft:b.getNode("altitude-ft").getValue(), bearing:bearing});
				if (adist_m < ac_closest_distance) {
					ac_closest_distance = adist_m;
					ac_closest = ac_i;
				}
				ac_i += 1;
			}
		}
#		var vor_h = 0;
		if (size(ac_list) >= ac_closest and ac_closest != -1) {
#			vor_h = 360 - ac_list[ac_closest].bearing - c_head_deg;
			setprop("instrumentation/tracking/ai-size", ac_i);
		} else {
			if (getprop("instrumentation/tracking/mode") == 1) {
				setprop("instrumentation/tracking/mode", 0);
			}
			setprop("instrumentation/tracking/ai-size", -1);
		}
#		setprop("instrumentation/tracking/ai1-heading-offset", vor_h);
		var ac_closest = -1;
		var ac_closest_distance = 999999;
		if (mp != nil) {
			var s = size(mp);
			for (var i = 0 ; i < s ; i += 1) {
				if(mp[i].getNode("callsign") != nil and mp[i].getNode("valid").getValue()) {
					var b = mp[i].getNode("position");
					var alat = b.getNode("latitude-deg").getValue();
					var alon = b.getNode("longitude-deg").getValue();
					var avglat = (c_lat + alat) / 2;
					var y = alat - c_lat;
					var x_grid = alon - c_lon;
					if (abs(x_grid) > 180) {
						if (alon < -90) {
							c_lon -= 360.0;
						} else {
							c_lon += 360.0;
						}
						x_grid = alon - c_lon;
					}
					if (avglat < 90 and avglat > -90) {
						var x = x_grid * cos(avglat);
					} else {
						print ("Error detected in mp section, line 212  avglat= ",avglat);
						var x = x_grid * cos(c_lat);
					}
					var ah1 = sin(y * 0.5);
					var ah2 = sin(x * 0.5);
					var adist_m = 2.0 * ERAD * asin(math.sqrt(ah1 * ah1 + cos(alat) * cos(c_lat) * ah2 * ah2));
					var xy_hyp = math.sqrt((x * x) + (y * y));
					var head = (xy_hyp == 0 ? 0 : asin(x / xy_hyp)) * 180 / math.pi;
					head = (c_lat > alat ? normheading(180 - head) : normheading(head));
					var bearing = normbearing(head, c_head_deg);
					append(ac_list, { type: 2, callsign:mp[i].getNode("callsign").getValue(), index:i, dist_m:adist_m, alt_ft:b.getNode("altitude-ft").getValue(), bearing:bearing});
					if (adist_m < ac_closest_distance) {
						ac_closest_distance = adist_m;
						ac_closest = ac_i;
					}
					ac_i += 1;
				}
			}
		}
# add walker to list
		if (getprop("sim/walker/outside")) {
			var alat = getprop("sim/walker/latitude-deg");
			var alon = getprop("sim/walker/longitude-deg");
			var avglat = (c_lat + alat) / 2;
			var y = alat - c_lat;
			var x_grid = alon - c_lon;
			if (abs(x_grid) > 180) {
				if (alon < -90) {
					c_lon -= 360.0;
				} else {
					c_lon += 360.0;
				}
				x_grid = alon - c_lon;
			}
			if (avglat < 90 and avglat > -90) {
				var x = x_grid * cos(avglat);
			} else {
				print ("Error detected in walker section, line 264  avglat= ",avglat);
				var x = x_grid * cos(c_lat);
			}
			var ah1 = sin(y * 0.5);
			var ah2 = sin(x * 0.5);
			var adist_m = 2.0 * ERAD * asin(math.sqrt(ah1 * ah1 + cos(alat) * cos(c_lat) * ah2 * ah2));
			var xy_hyp = math.sqrt((x * x) + (y * y));
			var head = (xy_hyp == 0 ? 0 : asin(x / xy_hyp)) * 180 / math.pi;
			head = (c_lat > alat ? normheading(180 - head) : normheading(head));
			var bearing = normbearing(head, c_head_deg);
			append(ac_list, { type: 2, callsign:"Walker", index:0, dist_m:adist_m, alt_ft:getprop("sim/walker/altitude-ft"), bearing:bearing});
			if (adist_m < ac_closest_distance) {
				ac_closest_distance = adist_m;
				ac_closest = ac_i;
			}
			ac_i += 1;
		}
#		vor_h = 0;
		if (size(ac_list) >= ac_closest and ac_closest != -1) {
#			vor_h = 360 - ac_list[ac_closest].bearing - c_head_deg;
			setprop("instrumentation/tracking/mp-size", ac_i);
		} else {
			setprop("instrumentation/tracking/mp-size", -1);
		}
#		setprop("instrumentation/tracking/mp1-heading-offset", vor_h);
		var sac = sort(ac_list, func(a,b) { return (a.dist_m > b.dist_m) });
		var s = size(sac);
		var ai_i_previous = ai_i;
		var mp_i_previous = mp_i;
		ai_i = 1;
		mp_i = 1;
		for (var i = 0 ; (i < s and i <= 13) ; i += 1) {
			setprop("instrumentation/display-screens/t2L-" ~ (i+3) ~ "a", sac[i].callsign);
			var txt2d = sprintf(m_conv_format[a_mode],m_2_conv[a_mode]*sac[i].dist_m) ~ m_conv_units[a_mode];
			var altn = ft_2_conv[a_mode]*sac[i].alt_ft;
#			if (altn < 10000) { 
#				if (altn < 100) {
#					if (altn < 1) {
#						var txt2a = "   " ~ sprintf(ft_conv_format[a_mode],altn) ~ ft_conv_units[a_mode];
#					} else {
#						var txt2a = "  " ~ sprintf(ft_conv_format[a_mode],altn) ~ ft_conv_units[a_mode];
#					}
#				} else {
#					var txt2a = " " ~ sprintf(ft_conv_format[a_mode],altn) ~ ft_conv_units[a_mode];
#				}
#			} else {
				var txt2a = sprintf(ft_conv_format[a_mode],altn) ~ ft_conv_units[a_mode];
#			}
			var txt2h = sprintf(" %3i",sac[i].bearing);
			setprop("instrumentation/display-screens/t2L-" ~ (i+3) ~ "b", txt2d ~ txt2a);
			setprop("instrumentation/display-screens/t2L-" ~ (i+3) ~ "c", txt2h);

			if ((ai_i <= 4) and (sac[i].type == 1)) {
				setprop("instrumentation/tracking/ai" ~ ai_i ~ "-callsign", sac[i].callsign);
				setprop("instrumentation/tracking/ai" ~ ai_i ~ "-distance-m", sac[i].dist_m);
				setprop("instrumentation/tracking/ai" ~ ai_i ~ "-bearing-deg", sac[i].bearing);
				setprop("instrumentation/tracking/ai" ~ ai_i ~ "-to", bearing_to(sac[i].bearing));
				var e_m = (sac[i].alt_ft - c_alt) * 0.3048;
				var xy_hyp = math.sqrt((e_m * e_m) + (sac[i].dist_m * sac[i].dist_m));
				var ze = (xy_hyp == 0 ? 0 : asin(e_m / xy_hyp)) * 180 / math.pi;
				setprop("instrumentation/tracking/ai" ~ ai_i ~ "-elevation-deg", ze);
				ai_i += 1;
			}
			if ((mp_i <= 4) and (sac[i].type == 2)) {
				setprop("instrumentation/tracking/mp" ~ mp_i ~ "-callsign", sac[i].callsign);
				setprop("instrumentation/tracking/mp" ~ mp_i ~ "-distance-m", sac[i].dist_m);
				setprop("instrumentation/tracking/mp" ~ mp_i ~ "-bearing-deg", sac[i].bearing);
				setprop("instrumentation/tracking/mp" ~ mp_i ~ "-to", bearing_to(sac[i].bearing));
				var e_m = (sac[i].alt_ft - c_alt) * 0.3048;
				var xy_hyp = math.sqrt((e_m * e_m) + (sac[i].dist_m * sac[i].dist_m));
				var ze = (xy_hyp == 0 ? 0 : asin(e_m / xy_hyp)) * 180 / math.pi;
				setprop("instrumentation/tracking/mp" ~ mp_i ~ "-elevation-deg", ze);
				mp_i += 1;
			}
		}
		if (ai_i_previous != ai_i) {
			for (var i = ai_i ; i <= 4; i += 1) {
				setprop("instrumentation/tracking/ai" ~ i ~ "-callsign", " ");
				setprop("instrumentation/tracking/ai" ~ i ~ "-distance-m", -999999);
				setprop("instrumentation/tracking/ai" ~ i ~ "-elevation-deg", -99);
			}
		}
		if (mp_i_previous != mp_i) {
			for (var i = mp_i ; i <= 4; i += 1) {
				setprop("instrumentation/tracking/mp" ~ i ~ "-callsign", " ");
				setprop("instrumentation/tracking/mp" ~ i ~ "-distance-m", -999999);
				setprop("instrumentation/tracking/mp" ~ i ~ "-elevation-deg", -99);
			}
		}
	}
}

var ac_loop_id = 0;
var ac_loop = func (id) {
	id == ac_loop_id or return;
	if (c_view == 0) {
		var ac = props.globals.getNode("ai/models").getChildren("aircraft");
		if ((aiac == nil) or (tracking_on)) {
			aiac = ac;	# copy of node vector
			ac_update();
		}
	}
	if (tracking_on) {
		settimer(func { ac_loop(ac_loop_id += 1) }, refresh_2L);
	}
}

# ======== fixed airport tracking and homing ========================
var ap2_callsign_Node = props.globals.getNode("instrumentation/tracking/ap2-callsign", 1);
var ap2_name_Node = props.globals.getNode("instrumentation/tracking/ap2-name", 1);
#var ap2_heading_offset_Node = props.globals.getNode("instrumentation/tracking/ap2-heading-offset", 1);
var ap2_dist_Node = props.globals.getNode("instrumentation/tracking/ap2-distance-m", 1);
var ap2_lat_Node = props.globals.getNode("instrumentation/tracking/ap2-lat", 1);
var ap2_lon_Node = props.globals.getNode("instrumentation/tracking/ap2-lon", 1);
var ap2_elev_Node = props.globals.getNode("instrumentation/tracking/ap2-elevation-deg", 1);
var ap2_heading_Node = props.globals.getNode("instrumentation/tracking/ap2-heading-deg", 1);
var ap2_bearing_Node = props.globals.getNode("instrumentation/tracking/ap2-bearing-deg", 1);
var ap2_range_Node = props.globals.getNode("instrumentation/tracking/ap2-range", 1);
var ap2 = nil;

var ap2c_L = nil;
ap2_callsign_Node.setValue(getprop("sim/startup/options/airport"));

var id = "";
var node = props.globals.getNode("/sim/gui/dialogs/airports", 1);
if (node.getNode("list") == nil)
	node.getNode("list", 1).setValue("");

node = node.getNode("list");

var listbox_apply = func {
	id = pop(split(" ", node.getValue()));
	id = substr(id, 1, size(id) - 2);  # strip parentheses
	ap2_callsign_Node.setValue(id);
}

var apply = func {
	id = string.uc(pop(split(" ", node.getValue())));
	ap2_callsign_Node.setValue(id);
}

var ap2_dialog = nil;
var ap_dialog = func {
	name = "Airport Callsign";
	if (ap2_dialog != nil) {
		fgcommand("dialog-close", props.Node.new({ "dialog-name" : name }));
		ap2_dialog = nil;
		return;
	}

	ap2_dialog = gui.Widget.new();
	ap2_dialog.set("layout", "vbox");
	ap2_dialog.set("name", name);
	var x = getprop("/sim/startup/xsize") / 2;
	ap2_dialog.set("x", x);
	ap2_dialog.set("y", "/sim/startup/ysize");

	var titlebar = ap2_dialog.addChild("group");
	titlebar.set("layout", "hbox");
	titlebar.addChild("empty").set("stretch", 1);
	titlebar.addChild("text").set("label", "Select Airport for Homing and Tracking");
	titlebar.addChild("empty").set("stretch", 1);

	var w = titlebar.addChild("button");
	w.set("pref-width", 16);
	w.set("pref-height", 16);
	w.set("legend", "");
	w.set("default", 1);
	w.set("keynum", 27);
	w.set("border", 1);
	w.prop().getNode("binding[0]/command", 1).setValue("nasal");
	w.prop().getNode("binding[0]/script", 1).setValue("ap2_dialog = nil");
	w.prop().getNode("binding[1]/command", 1).setValue("dialog-close");

	ap2_dialog.addChild("hrule").addChild("dummy");

	var a = ap2_dialog.addChild("airport-list");
	a.set("name", "airport-list");
	a.set("pref-width", 440);
	a.set("pref-height", 160);
	a.set("property", "/sim/gui/dialogs/airports/list");
	a.prop().getNode("binding[0]/command", 1).setValue("dialog-apply");
	a.prop().getNode("binding[0]/object-name", 1).setValue("airport-list");
	a.prop().getNode("binding[1]/command", 1).setValue("nasal");
	a.prop().getNode("binding[1]/script", 1).setValue("displayScreens.listbox_apply()");

	var g = ap2_dialog.addChild("group");
	g.set("layout", "hbox");
	g.addChild("empty").set("pref-width", 8);
	var content = g.addChild("input");
	content.set("name", "input");
	content.set("layout", "hbox");
	content.set("halign", "fill");
	content.set("border", 1);
	content.set("editable", 1);
	content.set("property", "/sim/gui/dialogs/airports/list");
	content.prop().getNode("binding[0]/command", 1).setValue("dialog-apply");
	content.prop().getNode("binding[0]/object-name", 1).setValue("input");
	content.prop().getNode("binding[1]/command", 1).setValue("dialog-update");
	content.prop().getNode("binding[1]/object-name", 1).setValue("airport-list");

	var box = g.addChild("button");
	box.set("legend", "Search");
#	box.set("halign", "left");
	box.set("label", "");
	box.set("pref-height", 18);
	box.set("border", 2);
	box.prop().getNode("binding[0]/command", 1).setValue("dialog-apply");
	box.prop().getNode("binding[0]/object-name", 1).setValue("input");
	box.prop().getNode("binding[1]/command", 1).setValue("dialog-update");
	box.prop().getNode("binding[1]/object-name", 1).setValue("airport-list");

	var box = g.addChild("button");
	box.set("halign", "right");
	box.set("legend", "Set");
	box.set("pref-width", 100);
	box.set("pref-height", 18);
	box.set("border", 2);
	box.prop().getNode("binding[0]/command", 1).setValue("dialog-apply");
	box.prop().getNode("binding[0]/object-name", 1).setValue("input");
	box.prop().getNode("binding[1]/command", 1).setValue("nasal");
	box.prop().getNode("binding[1]/script", 1).setValue("displayScreens.apply()");
	g.addChild("empty").set("pref-width", 8);

	ap2_dialog.addChild("empty").set("pref-height", "3");
	fgcommand("dialog-new", ap2_dialog.prop());
	gui.showDialog(name);
}

var ap2_update = func {
	var c_lat = getprop("position/latitude-deg");
	var c_lon = getprop("position/longitude-deg");
	var c_head_deg = getprop("orientation/heading-deg");
	if (ap2 != nil) {
		var avglat = (c_lat + ap2.lat) / 2;
		var y = ap2.lat - c_lat;
		var x_grid = ap2.lon - c_lon;
		if (abs(x_grid) > 180) {	# international date line
			if (ap2.lon < -90) {
				c_lon -= 360.0;
			} else {
				c_lon += 360.0;
			}
			x_grid = ap2.lon - c_lon;
		}
		var x = x_grid * cos(avglat);
		var xy_hyp = math.sqrt((x * x) + (y * y));
		var head = (xy_hyp == 0 ? 0 : asin(x / xy_hyp)) * 180 / math.pi;
		head = (c_lat > ap2.lat ? normheading(180 - head) : normheading(head));
		var bearing = normbearing(head, c_head_deg);
		ap2_bearing_Node.setValue(bearing);
		ap2_heading_Node.setValue(head);
		setprop("instrumentation/tracking/ap2-to", bearing_to(bearing));
		var range = walk.distFromCraft(ap2.lat, ap2.lon);
		ap2_dist_Node.setValue(range);
		var c_alt = getprop("position/altitude-ft");
		var e_m = ap2.elevation - (c_alt * 0.3048);
		var xy_hyp = math.sqrt((e_m * e_m) + (range * range));
		var ze = (xy_hyp == 0 ? 0 : asin(e_m / xy_hyp)) * 180 / math.pi;
		ap2_elev_Node.setValue(ze);
		range = range * m_2_conv[a_mode];
		var txt18 = sprintf("%7.2f",range) ~ m_conv_units[a_mode];
		ap2_range_Node.setValue(txt18);
	} else {
		ap2_bearing_Node.setValue(0);
		ap2_dist_Node.setValue(-999999);
	}
}

var ap2_loop_id = 0;
var ap2_loop = func (id) {
	id == ap2_loop_id or return;
	if (c_view == 0) {
		ap2_update();
	}
	settimer(func { ap2_loop(id) }, 0.95);
}

settimer(func { ap2_loop(ap2_loop_id += 1) }, 3);

# ======== combined aircraft and airport section ===================
var apt = nil;
var aiac = nil;
settimer(func { apt_loop(apt_loop_id += 1) }, 2);

settimer(func { apt_update(apt_update_id += 1) }, 3);

# ======== scroll screen-2L and screen-2R ==========================
var screen_2L_on = 0;
var scroll_2L = func (newtext) {
	if (screen_2L_on) {
		setprop("instrumentation/display-screens/t2L-2", getprop("instrumentation/display-screens/t2L-3"));
		setprop("instrumentation/display-screens/t2L-3", getprop("instrumentation/display-screens/t2L-4"));
		setprop("instrumentation/display-screens/t2L-4", getprop("instrumentation/display-screens/t2L-5"));
		setprop("instrumentation/display-screens/t2L-5", getprop("instrumentation/display-screens/t2L-6"));
		setprop("instrumentation/display-screens/t2L-6", getprop("instrumentation/display-screens/t2L-7"));
		setprop("instrumentation/display-screens/t2L-7", getprop("instrumentation/display-screens/t2L-8"));
		setprop("instrumentation/display-screens/t2L-8", getprop("instrumentation/display-screens/t2L-9"));
		setprop("instrumentation/display-screens/t2L-9", getprop("instrumentation/display-screens/t2L-10"));
		setprop("instrumentation/display-screens/t2L-10", getprop("instrumentation/display-screens/t2L-11"));
		setprop("instrumentation/display-screens/t2L-11", getprop("instrumentation/display-screens/t2L-12"));
		setprop("instrumentation/display-screens/t2L-12", getprop("instrumentation/display-screens/t2L-13"));
		setprop("instrumentation/display-screens/t2L-13", getprop("instrumentation/display-screens/t2L-14"));
		setprop("instrumentation/display-screens/t2L-14", getprop("instrumentation/display-screens/t2L-15"));
		setprop("instrumentation/display-screens/t2L-15", getprop("instrumentation/display-screens/t2L-16"));
		setprop("instrumentation/display-screens/t2L-16", newtext);
	}
}

var init = func {
	setlistener("instrumentation/digital/altitude-mode", func(n) a_mode = n.getValue(), 1);

	setlistener("instrumentation/display-screens/refresh-2L-sec", func(n) refresh_2L = n.getValue());

	setlistener("sim/current-view/view-number", func(n) c_view = n.getValue());

	setlistener("instrumentation/tracking/ai-size", func {
		cleanup_2L();
	},,0);

	setlistener("instrumentation/tracking/mp-size", func {
		cleanup_2L();
	},,0);

	setlistener("instrumentation/tracking/enabled", func(n) {
		tracking_on = n.getValue();
		if (tracking_on) {
			setprop("instrumentation/display-screens/t2L-1", "NEARBY AIRCRAFT");
			setprop("instrumentation/display-screens/t2L-2", "Callsign                 Distance   Altitude   Bearing");
			setprop("instrumentation/tracking/ai-size", -1);
			setprop("instrumentation/tracking/ai1-distance-m", -999999);
			settimer(func { ac_loop(ac_loop_id += 1) }, 0);
		}
	}, 1, 0);

	ap2c_L = setlistener("instrumentation/tracking/ap2-callsign", func(n) {
		ap2 = airportinfo(n.getValue());
		if (ap2 != nil) {
			ap2_name_Node.setValue(ap2.name);
			ap2_lat_Node.setValue(ap2.lat);
			ap2_lon_Node.setValue(ap2.lon);
			ap2_elev_Node.setValue(ap2.elevation);
			ap2_update();
		}
	}, 1);

	setlistener("sim/signals/reinit", func {
		apt = nil;
		aiac = nil;
	});
}
settimer(init,0);
