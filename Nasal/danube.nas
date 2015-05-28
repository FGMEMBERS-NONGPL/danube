# ===== Danube class Runabout  version 41.6 for FlightGear 1.9 =====

# config file entries ===============================================
# save livery choice in your config file to autoload next start
aircraft.data.add("sim/model/livery/name");
aircraft.data.add("sim/model/danube/shadow");
aircraft.data.add("sim/model/danube/insignia/number");

# strobes -----------------------------------------------------------
var strobe_switch = props.globals.getNode("controls/lighting/strobe", 1);
aircraft.light.new("sim/model/danube/lighting/strobe1", [0.1, 1.4], strobe_switch);

# beacons -----------------------------------------------------------
var beacon_switch = props.globals.getNode("controls/lighting/beacon", 1);
aircraft.light.new("sim/model/danube/lighting/beacon1", [0.25, 1.25], beacon_switch);

# interior lighting -------------------------------------------------
var alert_switch_Node = props.globals.getNode("controls/lighting/alert", 1);
aircraft.light.new("sim/model/danube/lighting/alert1", [2.0, 0.75], alert_switch_Node);
# /sim/model/danube/lighting/alert1/state is destination, alert_level drifts to chase alert_state

# Hull and fuselage colors and livery ====================================
aircraft.livery.init("Aircraft/danube/Models/Liveries");

var doorProximityVolume = func (current_view, door,x,y) {
	if (current_view) {	# outside view
		if (current_view == view.indexof("Walk View")) {
			var distToDoor_m = walk.distFromCraft(getprop("sim/walker/latitude-deg"),getprop("sim/walker/longitude-deg")) - 10;
			if (distToDoor_m < 0) {
				distToDoor_m = 0;
			}
			if (door >= 2) {
				distToDoor_m = distToDoor_m * 3;
			}
		} else {
			if (door >= 2) {
				return 0.1;
			} else {
				return 0.5;
			}
		}
	} else {
		var a = (x - door_coord_x_m[door]);
		var b = (y - door_coord_y_m[door]);
		var distToDoor_m = math.sqrt(a * a + b * b);
	}
	if (distToDoor_m > 50) {
		return 0;
	} elsif (distToDoor_m > 25) {
		return (50 - distToDoor_m) / 250;
	} elsif (distToDoor_m > 10) {
		return (0.1 + ((25 - distToDoor_m) / 60));
	} else {
		return (0.35 + ((10 - distToDoor_m) / 15.3846));
	}
}

var clamp = func(v, min, max) { v < min ? min : v > max ? max : v }

# Add second popupTip to avoid being overwritten by primary joystick messages ===
var tipArg2 = props.Node.new({ "dialog-name" : "PopTip2" });
var currTimer2 = 0;
var popupTip2 = func {
	var delay2 = if(size(arg) > 1) {arg[1]} else {1.5};
	var tmpl2 = { name : "PopTip2", modal : 0, layout : "hbox",
		y: gui.screenHProp.getValue() - 110,
		text : { label : arg[0], padding : 6 } };

	fgcommand("dialog-close", tipArg2);
	fgcommand("dialog-new", props.Node.new(tmpl2));
	fgcommand("dialog-show", tipArg2);

	currTimer2 = currTimer2 + delay2;
	var thisTimer2 = currTimer2;

		# Final argument is a flag to use "real" time, not simulated time
	settimer(func { if(currTimer2 == thisTimer2) { fgcommand("dialog-close", tipArg2); } }, delay2, 1);
}

#==========================================================================
#             === define global nodes and constants ===

# define damage variables -------------------------------------------
	# significant damage occurs above 50 impacts, each exceeding 600 fps per clock cycle
	# changing this number also requires changing <value> and <ind> in both xml files.
var destruction_threshold = 50;

# view nodes and offsets --------------------------------------------
var zNoseNode = props.globals.getNode("sim/view/config/y-offset-m", 1);
var xViewNode = props.globals.getNode("sim/current-view/z-offset-m", 1);
var yViewNode = props.globals.getNode("sim/current-view/x-offset-m", 1);
var hViewNode = props.globals.getNode("sim/current-view/heading-offset-deg", 1);
var vertical_offset_ft = 5.2;
	# keep shadow off ground at expense of appearing to float
	# touching ground should be offset of 1.5m or 4.92 ft.
	# any changes to vertical_offset should also be made to
	# Models/danube.xml line# 2886 

# nav lights --------------------------------------------------------
var nav_lights_state = props.globals.getNode("sim/model/danube/lighting/nav-lights-state", 1);
var nav_light_switch = props.globals.getNode("sim/model/danube/lighting/nav-light-switch", 1);

# landing lights ----------------------------------------------------
var landing_light_switch = props.globals.getNode("sim/model/danube/lighting/landing-lights", 1);

# doors -------------------------------------------------------------
var doors = [];
var doortiming = [2.85, 2.85, 1.25, 1.25];  # different timing for different size doors

# movement and position ---------------------------------------------
var airspeed_kt_Node = props.globals.getNode("velocities/airspeed-kt", 1);
var abs_airspeed_Node = props.globals.getNode("velocities/abs-airspeed-kt", 1);

# maximum speed for ufo model at 100% throttle ----------------------
var maxspeed = props.globals.getNode("engines/engine/speed-max-mps", 1);
var speed_mps = [1, 20, 50, 100, 200, 500, 1000, 2000, 5000, 11176, 20000, 50000];
# level 9 maximum speed 11176mps is 25000mph. aka escape velocity.
# level 10 is not really useful without interplanetary capabilities,
#  and is not allowed below the boundary to space.
var limit = [1, 5, 6, 7, 1, 5, 6, 11];
var current = props.globals.getNode("engines/engine/speed-max-powerlevel", 1);

# VTOL anti-grav ----------------------------------------------------
var joystick_elevator = props.globals.getNode("input/joysticks/js/axis[1]/binding/setting", 1);
var antigrav = { input_type: 0, momentum_watch: 0, momentum: 0, up_factor: 0, request: 0 };
	# input_type ; 1 = keyboard, 2 = joystick, 3 = mouse
	# request = for during startup, includes timer to cancel request if no further requests are made. Returns to zero after complete.

# ground detection and adjustment -----------------------------------
var altitude_ft_Node = props.globals.getNode("position/altitude-ft", 1);
var ground_elevation_ft = props.globals.getNode("position/ground-elev-ft", 1);
var pitch_deg = props.globals.getNode("orientation/pitch-deg", 1);
var roll_deg = props.globals.getNode("orientation/roll-deg", 1);
var roll_control = props.globals.getNode("controls/flight/aileron", 1);
var pitch_control = props.globals.getNode("controls/flight/elevator", 1);

# interior lighting and emissions -----------------------------------
var livery_cabin_surface = [	# A=ambient from livery, only updates upon livery change
				# _add= factor to calculate ambient from livery accounting for alert_level
				# E=calculated emissions
	{ AR: 0.045, AG: 0.047, AB: 0.047, R_add: 0     , G_add: 0     , B_add: 0     , ER: 0, EG: 0, EB: 0, pname: "interiorC-light-frame", type:"GB", in_livery:0},
	{ AR: 0.990, AG: 0.940, AB: 0.940, R_add: 0     , G_add: 0     , B_add: 0     , ER: 0, EG: 0, EB: 0, pname: "interior1-frame-walls3", type:"", in_livery:1},
	{ AR: 0.890, AG: 0.730, AB: 0.760, R_add: 0     , G_add: 0     , B_add: 0     , ER: 0, EG: 0, EB: 0, pname: "interior2-walls1", type:"", in_livery:1},
	{ AR: 0.850, AG: 0.850, AB: 0.850, R_add: 0.42  , G_add:-0.212 , B_add:-0.212 , ER: 0, EG: 0, EB: 0, pname: "interior3-door-frame", type:"GB", in_livery:0},
	{ AR: 0.530, AG: 0.510, AB: 0.510, R_add: 0     , G_add: 0     , B_add: 0     , ER: 0, EG: 0, EB: 0, pname: "interior4-ceiling-lower-walls4", type:"", in_livery:1},
	{ AR: 0.700, AG: 0.590, AB: 0.470, R_add: 0     , G_add: 0     , B_add: 0     , ER: 0, EG: 0, EB: 0, pname: "interior5-walls2", type:"", in_livery:1},
	{ AR: 0.188, AG: 0.135, AB: 0.113, R_add: 0.094 , G_add:-0.0338, B_add:-0.0283, ER: 0, EG: 0, EB: 0, pname: "interior6-table", type:"", in_livery:0},
	{ AR: 0.660, AG: 0.610, AB: 0.810, R_add: 0.300 , G_add:-0.150 , B_add:-0.200 , ER: 0, EG: 0, EB: 0, pname: "interior7-flooring", type:"", in_livery:1},
	{ AR: 0.113, AG: 0.009, AB: 0.008, R_add: 0.0565, G_add:-0.0023, B_add:-0.0188, ER: 0, EG: 0, EB: 0, pname: "interior8-window-frame", type:"", in_livery:0},
	{ AR: 0.970, AG: 0.930, AB: 0.990, R_add: 0     , G_add: 0     , B_add: 0     , ER: 0, EG: 0, EB: 0, pname: "interior9-seat-cover", type:"", in_livery:1},
	{ AR: 0.025, AG: 0.010, AB: 0.010, R_add: 0     , G_add: 0     , B_add: 0     , ER: 0, EG: 0, EB: 0, pname: "interiorD-door-panels", type:"", in_livery:0}
	];
var livery_cabin_count = size(livery_cabin_surface);
var interior_lighting_base_R = 0;   # base for calculating individual colors inside
var interior_lighting_base_GB = 0;  # Red, and GreenBlue

# Starfleet registration insignia ===================================
var insignia_node = props.globals.getNode("sim/model/danube/insignia/number", 1);
var gui_insignia_node = props.globals.getNode("/sim/gui/dialogs/insignia", 1);
var registry_list = [ { number: 72003, name: "USS Danube"},
	{ number: 72452, name: "USS Rio Grande"},
	{ number: 72453, name: "USS Yangtzee Kiang"},
	{ number: 72454, name: "USS Ganges"},
	{ number: 72617, name: "USS Mekong"},
	{ number: 72658, name: "USS Saskatchewan"},
	{ number: 72905, name: "USS Orinoco"},
	{ number: 72936, name: "USS Rubicon"},
	{ number: 73024, name: "USS Shenandoah"},
	{ number: 73121, name: "USS Shiawassee"},
	{ number: 73196, name: "USS Volga"},
	{ number: 74602, name: "USS Yukon"},
	{ number: 74751, name: "USS Yellowstone"}];
if (gui_insignia_node.getNode("list") == nil) {
	gui_insignia_node.getNode("list", 1).setValue("");
}

for (var i = 0; i < size(registry_list); i += 1) {
	gui_insignia_node.getNode("list["~i~"]", 1).setValue("NCC-"~registry_list[i].number~" "~registry_list[i].name);
}

var combobox_apply = func {
	var id = pop(split("NCC-",gui_insignia_node.getValue()));
	id = ((size(id) >= 5) ? (substr(id, 0, 5)) : 0);
	insignia_node.setValue(id);
}

#==========================================================================
#    === define nasal non-local variables at startup ===
# ------ components ------
var nacelleL_detached = 0;
var nacelleR_detached = 0;
# -------- damage --------
var damage_count = 0;
var lose_altitude = 0;   # drift or sink when damaged or power shuts down
var damage_blocker = 0;
# ------ nav lights ------
var sun_angle = 0;  # down to 0 at high noon, 2 at midnight, depending on latitude
var visibility = 16000;                # 16Km
# --------- doors --------
var door0_position = 0;
var door1_position = 0;
var door2_opened = 0;
var door3_opened = 0;
var door_auto_open = [0, 0, 1, 1];
var active_door = 0;
# -------- engines and main systems ------
	# engine refers to impulse engines
	# /sim/model/danube/lighting/engine-glow is a combination of engine sounds
	# anti-grav can provide hover capability (exclusively under 100 kts)
	# nacelles propulsion are powered by warp drive
	# stage 1 covers all forward flight modes up to 3900 kts.
	# stage 2 "increases plasma flow" so that orbital velocity can be attained
var power_switch = 1;		# no request in-between. power goes direct to state.
var impulse_request = 1;	# Request. level follows.
var impulse_level = 1;		# follows request, provides discharge delay when going off
var warp1_request = 1;
var warp1_level = 1;
var warp2_request = 1;
var warp2_level = 1;
var impulse_state = 0;		# destination level for impulse_level
var impulse_drift = 0;		# follows reactor_state
var warp_state = 0;		# state = destination level
var warp_drift = 0;
# ------- movement -------
airspeed_kt_Node.setValue(0);
abs_airspeed_Node.setValue(0);
var contact_altitude = 0;   # the altitude at which the model touches ground
var pitch_d = 0;
var airspeed = 0;
var asas = 0;
var engines_lvl = 0;
var hover_add = 0;              # increase in altitude to keep nacelles and nose from touching ground
var hover_target_altitude = 0;  # ground_elevation + hover_ft (does not include hover_add)
var h_contact_target_alt = 0;   # adjusted for contact altitude
var skid_last_value = 0;
# ------ submodel control -----
var nacelle_L_venting = 0;
var nacelle_R_venting = 0;
var venting_direction = -2;     # start disabled. -1=backward, 1=forward, 0=both
var shutdown_venting = 0;
# --- ground detection ---
var init_agl = 5;     # some airports reported elevation change after movement begins
var ground_near = 1;  # instrument panel indicator lights
var ground_warning = 1;
# ----- maximum speed ----
maxspeed.setValue(500);
current.setValue(5);  # needed for engine-digital panel
var cpl = 5;          # current power level
var current_to = 5;   # distinguishes between change_maximum types. Current or To
var max_drift = 0;    # smoothen drift between maxspeed power levels
var max_lose = 0;     # loss of momentum after shutdown of engines
var max_from = 5;
var max_to = 5;
# -------- sounds --------
var sound_level = 0;
var sound_state = 0;
var alert_level = 0;
# ------- interior -------
var alert_switch = 0;
var int_switch = 1;    # interior lights
var trans_switch = 1;  # transporter pad
# specular: 1 = full reflection, 0 = no reflection from sun
var cockpit_locations = [ { x: -13.2, y: 0.59, z: 0.66, h: 0, p: 0, fov: 55, can_walk: 0 },
		{ x: -10.2, y: 0, z: 1.025, h: 0, p: 0, fov: 55, can_walk: 1 },
		{ x: 4.0, y: 0, z: 1.025, h: 180, p: 0, fov: 55, can_walk: 1 },
		{ x: -11.98, y: 0, z: 0.72, h: 0, p: 0, fov: 55, can_walk: 0 },
		{ x: -12.194, y: -1.664, z: 0.78, h: 332, p: 0, fov: 55, can_walk: 0 },
		{ x: -13.2, y: -0.60, z: 0.89, h: 0, p: -8.9, fov: 55, can_walk: 0 } ];
		# Waldo eye height is 1.625m
var cockpitView = 0;         # start in right side cockpit
var active_nav_button = [3, 3, 1];
var active_landing_button = [3, 1, 3];
var config_dialog = nil;
var livery_dialog = nil;

# turn off rendering of transparent shadows
setprop("sim/rendering/shadows-ac-transp", 0);

var reinit_danube = func {   # make it possible to reset the above variables
	damage_blocker = 0;
	damage_count = 0;
	lose_altitude = 0;
	contact_altitude = 0;
	door0_position = 0;
	door1_position = 0;
	door2_opened = 0;
	door3_opened = 0;
	var door_auto_open = [0, 0, 1, 1];
	active_door = 0;
	power_switch = 1;
	impulse_request = 1;
	impulse_level = 1;
	warp1_request = 1;
	warp1_level = 1;
	warp2_request = 1;
	warp2_level = 1;
	antigrav.request = 0;
	impulse_state = 0;
	impulse_drift = 0;
	warp_state = 0;
	warp_drift = 0;
	pitch_d = 0;
	airspeed = 0;
	asas = 0;
	engines_lvl = 0;
	hover_add = 0;
	hover_target_altitude = 0;
	h_contact_target_alt = 0;
	skid_last_value = 0;
	nacelle_L_venting = 0;
	nacelle_R_venting = 0;
	venting_direction = -2;
	shutdown_venting = 0;
	init_agl = 5;
	cpl = 5;
	current_to = 5;
	max_drift = 0;
	max_lose = 0;
	max_from = 5;
	max_to = 5;
	sound_state = 0;
	alert_level = 0;
	int_switch = 1;
	trans_switch = 1;
	cockpitView = 0;
	cycle_cockpit(0);
	active_nav_button = [3, 3, 1];
	active_landing_button = [3, 1, 3];
	name = "danube-config";
	if (config_dialog != nil) {
		fgcommand("dialog-close", props.Node.new({ "dialog-name" : name }));
		config_dialog = nil;
	}
}

 setlistener("sim/signals/reinit", func {
	reinit_danube();
 });

# door functions ----------------------------------------------------

var init_doors = func {
	var id_i = 0;
	foreach (var id_d; props.globals.getNode("sim/model/danube/doors").getChildren("door")) {
		append(doors, aircraft.door.new(id_d, doortiming[id_i]));
		id_i += 1;
	}
}
settimer(init_doors, 0);

var next_door = func { select_door(active_door + 1, 1) }

var previous_door = func { select_door(active_door - 1, 1) }

var select_door = func(sd_number, verbose) {
	active_door = sd_number;
	if (active_door < 0) {
		active_door = size(doors) - 1;
	} elsif (active_door >= size(doors)) {
		active_door = 0;
	}
	if (verbose) {
		gui.popupTip("Selecting " ~ doors[active_door].node.getNode("name").getValue());
	}
}

var door_coord_x_m = [-9.953, -9.953, -8.741, 0.731];
var door_coord_y_m = [-2.281, 2.283, 0.012, 0.012];

var door_update = func(door_number) {
	var c_view = getprop("sim/current-view/view-number");
	var y_view_position = yViewNode.getValue();
	var x_view_position = xViewNode.getValue();
	var walker_x_position = getprop("sim/model/danube/crew/walker/x-offset-m");
	var walker_y_position = getprop("sim/model/danube/crew/walker/y-offset-m");
	if (door_number == 0) {
		door0_position = getprop("sim/model/danube/doors/door[0]/position-norm");
		# check for closing door while standing in doorway
		if (door0_position < 0.62) {
			if (x_view_position > -10.42 and x_view_position < -9.48) {
				# between front hatches
				if ((c_view == 0) and (y_view_position < -2.04)) {
					yViewNode.setValue(-2.04);
				}
			}
			if (walker_x_position > -10.42 and walker_x_position < -9.48) {
				if (walker_y_position < -2.04) {
					setprop("sim/model/danube/crew/walker/y-offset-m", -2.04);
				}
			}
		}
		setprop("sim/model/danube/sound/door0-volume", doorProximityVolume(c_view, 0, x_view_position, y_view_position));
	} elsif (door_number == 1) {
		door1_position = getprop("sim/model/danube/doors/door[1]/position-norm");
		if (door1_position < 0.62) {
			if (x_view_position > -10.42 and x_view_position < -9.48) {
				# between front hatches
				if ((c_view == 0) and (y_view_position > 2.04)) {
					yViewNode.setValue(2.04);
				}
			}
			if (walker_x_position > -10.42 and walker_x_position < -9.48) {
				if (walker_y_position > 2.04) {
					setprop("sim/model/danube/crew/walker/y-offset-m", 2.04);
				}
			}
		}
		setprop("sim/model/danube/sound/door1-volume", doorProximityVolume(c_view, 1, x_view_position, y_view_position));
	} elsif (door_number == 2) {
		setprop("sim/model/danube/sound/door2-volume", doorProximityVolume(c_view, 2, x_view_position, y_view_position));
	} elsif (door_number == 3) {
		setprop("sim/model/danube/sound/door3-volume", doorProximityVolume(c_view, 3, x_view_position, y_view_position));
	}
}


setlistener("sim/model/danube/doors/door[0]/position-norm", func {
	door_update(0);
});

setlistener("sim/model/danube/doors/door[1]/position-norm", func {
	door_update(1);
});

setlistener("sim/model/danube/doors/door[2]/position-norm", func {
	door_update(2);
});

setlistener("sim/model/danube/doors/door[3]/position-norm", func {
	door_update(3);
});

setlistener("sim/model/danube/doors/door[2]/auto-open", func(n) { door_auto_open[2] = n.getValue()});

setlistener("sim/model/danube/doors/door[3]/auto-open", func(n) { door_auto_open[3] = n.getValue()});

var toggle_door = func {
	var td_dr = doors[active_door].node.getNode("position-norm").getValue();
	if (active_door <= 1 ) {
		doors[active_door].toggle();
		setprop("sim/model/danube/sound/door-direction", td_dr);  # attempt to determine direction

		if (active_door == 0) {
			setprop("sim/model/danube/sound/hatch0-trigger", 1);
			settimer(reset_trigger0, 1);
		} elsif (active_door == 1) {
			setprop("sim/model/danube/sound/hatch1-trigger", 1);
			settimer(reset_trigger1, 1);
		}
	} else {
		var td_aop = door_auto_open[active_door];
		td_aop = (td_aop <= 1 ? td_aop + 1 : 0);
		setprop("sim/model/danube/doors/door[" ~ active_door ~ "]/auto-open", td_aop);
		var results_text = ["Lock closed","Automatic opening","Hold open"];
		popupTip2(results_text[td_aop]);
		if (td_aop == 0) {
			doors[active_door].close();
			if (active_door == 2) {
				door2_opened = 0;
			} else {
				door3_opened = 0;
			}
		} elsif (td_aop == 1) {
			check_auto_doors(xViewNode.getValue(),yViewNode.getValue());
		} else {
			doors[active_door].open();
			if (active_door == 2) {
				door2_opened = 1;
			} else {
				door3_opened = 1;
			}
		}
	}
}

# give hatch sound effect one second to play ------------------------
var reset_trigger0 = func {
	setprop("sim/model/danube/sound/hatch0-trigger", 0);
}

var reset_trigger1 = func {
	setprop("sim/model/danube/sound/hatch1-trigger", 0);
}

# systems -----------------------------------------------------------

setlistener("sim/model/danube/systems/power-switch", func(n) {
	power_switch = n.getValue();
	if (damage_count) {  # make sure when the power goes off that flaring turns to venting
		var ventingL = getprop("ai/submodels/pylon-L-venting");
		var ventingR = getprop("ai/submodels/pylon-R-venting");
		var flaringL = getprop("ai/submodels/pylon-L-flaring");
		var flaringR = getprop("ai/submodels/pylon-R-flaring");
		if (ventingL or flaringL) {
			if (power_switch) {
				if (ventingL) {
					setprop("ai/submodels/pylon-L-venting", 0);
					setprop("ai/submodels/pylon-L-flaring", 1);
				}
			} else {
				if (flaringL) {
					setprop("ai/submodels/pylon-L-flaring", 0);
					setprop("ai/submodels/pylon-L-venting", 1);
				}
			}
		}
		if (ventingR or flaringR) {
			if (power_switch) {
				if (ventingR) {
					setprop("ai/submodels/pylon-R-venting", 0);
					setprop("ai/submodels/pylon-R-flaring", 1);
				}
			} else {
				if (flaringR) {
					setprop("ai/submodels/pylon-R-flaring", 0);
					setprop("ai/submodels/pylon-R-venting", 1);
				}
			}
		}
	}
});

setlistener("sim/model/danube/systems/impulse-request", func(n) { impulse_request = n.getValue() },, 0);

setlistener("sim/model/danube/systems/impulse-level", func(n) { impulse_level = n.getValue() },, 0);

setlistener("sim/model/danube/lighting/engine-glow", func(n) { engines_lvl = n.getValue() },, 0);

setlistener("sim/model/danube/systems/warp1-request", func(n) { warp1_request = n.getValue() },, 0);

setlistener("sim/model/danube/systems/warp1-level", func(n) { warp1_level = n.getValue() },, 0);

setlistener("sim/model/danube/systems/warp2-request", func(n) { warp2_request = n.getValue() },, 0);

# interior ----------------------------------------------------------

setlistener("sim/model/danube/lighting/interior-switch", func(n) { int_switch = n.getValue() },, 0);

setlistener("sim/model/danube/lighting/transporter-overhead", func(n) { trans_switch = n.getValue() },, 0);

# lighting and texture ----------------------------------------------

setlistener("environment/visibility-m", func(n) { visibility = n.getValue() }, 1, 0);

var emis_calc = 0.7;
setlistener("sim/model/danube/lighting/overhead/emission/factor", func(n) { emis_calc = n.getValue() }, 1, 0);
var amb_calc = 0.1;
setlistener("sim/model/danube/lighting/interior-ambient-factor", func(n) { amb_calc = n.getValue() }, 1, 0);

var set_ambient_I = func(i) {
	# emission calculation base
	livery_cabin_surface[i].ER = livery_cabin_surface[i].AR + (livery_cabin_surface[i].R_add * alert_level * int_switch * power_switch);
	setprop("sim/model/danube/lighting/"~livery_cabin_surface[i].pname~"/amb-dif/red", livery_cabin_surface[i].ER * amb_calc);
	livery_cabin_surface[i].EG = livery_cabin_surface[i].AG + (livery_cabin_surface[i].G_add * alert_level * int_switch * power_switch);
	if (livery_cabin_surface[i].type == "GB") {
		setprop("sim/model/danube/lighting/"~livery_cabin_surface[i].pname~"/amb-dif/gb", livery_cabin_surface[i].EG * amb_calc);
	} else {
		livery_cabin_surface[i].EB = livery_cabin_surface[i].AB + (livery_cabin_surface[i].B_add * alert_level * int_switch * power_switch);
		setprop("sim/model/danube/lighting/"~livery_cabin_surface[i].pname~"/amb-dif/green", livery_cabin_surface[i].EG * amb_calc);
		setprop("sim/model/danube/lighting/"~livery_cabin_surface[i].pname~"/amb-dif/blue", livery_cabin_surface[i].EB * amb_calc);
	}
}

var recalc_material_I = func(i) {
	# calculate emission and ambient base levels upon loading new livery
	var red_amb_flr_R = clamp(livery_cabin_surface[i].AR * 1.5, 0.5, 1.0);     # tint calculations
	livery_cabin_surface[i].R_add = red_amb_flr_R - livery_cabin_surface[i].AR;  # amount to add when calculating alert_level
	var red_amb_flr_G = clamp(livery_cabin_surface[i].AG * 0.75, 0, 1);
	livery_cabin_surface[i].G_add = red_amb_flr_G - livery_cabin_surface[i].AG;
	if (livery_cabin_surface[i].type != "GB") {
		var red_amb_flr_B = clamp(livery_cabin_surface[i].AB * 0.75, 0, 1);
		livery_cabin_surface[i].B_add = red_amb_flr_B - livery_cabin_surface[i].AB;
	}
}

setlistener("controls/lighting/alert", func {
	alert_switch = alert_switch_Node.getValue();
	alert_level = alert_switch;  # reset brightness to full upon change
	if (!alert_switch) {
		setprop("sim/model/danube/lighting/overhead/emission/red", int_switch);
		setprop("sim/model/danube/lighting/overhead/emission/gb", int_switch);
		setprop("sim/model/danube/lighting/waldo/emission/gb", int_switch);
	}
	for (var i = 0; i < livery_cabin_count; i += 1) {
		if (livery_cabin_surface[i].in_livery == 1) {
			recalc_material_I(i);
		}
	}
	interior_lighting_update();
},, 0);

# watch for damage --------------------------------------------------

setlistener("sim/model/danube/components/nacelle-L-detached", func(n) {
	nacelleL_detached = n.getValue();
	if (nacelleL_detached) {
		if (nacelle_L_venting) {
			setprop("sim/model/danube/systems/nacelle-L-venting", 0);
			setprop("ai/submodels/pylon-L-flaring", 1);
		}
	}
}, 1);

setlistener("sim/model/danube/components/nacelle-R-detached", func(n) {
	nacelleR_detached = n.getValue();
	if (nacelleR_detached) {
		if (nacelle_R_venting) {
			setprop("sim/model/danube/systems/nacelle-R-venting", 0);
			setprop("ai/submodels/pylon-R-flaring", 1);
		}
	}
}, 1);

var update_venting = func(uv_change, left_right) {	# 1=left,2=right
	var old_direction = venting_direction;
	var new_venting = 0;
	if (nacelle_L_venting or nacelle_R_venting) {
		# make venting submodels appear realistic as wind direction blows them
		if (airspeed > 10) {
			venting_direction = 1;
		} elsif (airspeed < -10) {
			venting_direction = -1;
		} else {
			venting_direction = 0;
		}
		if ((old_direction != venting_direction) or (uv_change)) {
			if (nacelle_L_venting) {
				if (!nacelleL_detached) {
					if (venting_direction == 1) {
						setprop("ai/submodels/nacelle-LR-venting", 1);
						setprop("ai/submodels/nacelle-LF-venting", 0);
					} elsif (venting_direction == -1) {
						setprop("ai/submodels/nacelle-LR-venting", 0);
						setprop("ai/submodels/nacelle-LF-venting", 1);
					} elsif (venting_direction == 0) {
						setprop("ai/submodels/nacelle-LR-venting", 1);
						setprop("ai/submodels/nacelle-LF-venting", 1);
					}
					new_venting = 1;
				} else {
					setprop("ai/submodels/pylon-L-flaring", 1);
					setprop("ai/submodels/pylon-L-venting", 1);
				}
			} else {
				setprop("ai/submodels/nacelle-LR-venting", 0);
				setprop("ai/submodels/nacelle-LF-venting", 0);
			}
			if (nacelle_R_venting) {
				if (!nacelleR_detached) {
					if (venting_direction == 1) {
						setprop("ai/submodels/nacelle-RR-venting", 1);
						setprop("ai/submodels/nacelle-RF-venting", 0);
					} elsif (venting_direction == -1) {
						setprop("ai/submodels/nacelle-RR-venting", 0);
						setprop("ai/submodels/nacelle-RF-venting", 1);
					} elsif (venting_direction == 0) {
						setprop("ai/submodels/nacelle-RR-venting", 1);
						setprop("ai/submodels/nacelle-RF-venting", 1);
					}
					new_venting += 2;
				} else {
					setprop("ai/submodels/pylon-R-flaring", 1);
					setprop("ai/submodels/pylon-R-venting", 1);
				}
			} else {
				setprop("ai/submodels/nacelle-RR-venting", 0);
				setprop("ai/submodels/nacelle-RF-venting", 0);
			}
		}
	} else {
		venting_direction = -3;
		if (uv_change) {
			setprop("ai/submodels/nacelle-LR-venting", 0);
			setprop("ai/submodels/nacelle-LF-venting", 0);
			setprop("ai/submodels/nacelle-RR-venting", 0);
			setprop("ai/submodels/nacelle-RF-venting", 0);
		}
	}
	if (left_right != new_venting) {
		if ((left_right != 2) and ((new_venting == 0) or (new_venting == 2))) {
			setprop("sim/model/danube/systems/nacelle-L-venting", 0);
		} elsif ((left_right != 1) and (new_venting <= 1)) {
			setprop("sim/model/danube/systems/nacelle-R-venting", 0);
		}
	}
}

setlistener("sim/model/danube/systems/nacelle-L-venting", func(n) {
	nacelle_L_venting = n.getValue();
	update_venting(1,1);
}, 1);

setlistener("sim/model/danube/systems/nacelle-R-venting", func(n) {
	nacelle_R_venting = n.getValue();
	update_venting(1,2);
}, 1);

#==========================================================================

var panel_lighting_update = func {
	var ipsa = (power_switch > 0 ? ((sun_angle - 1.1) * 3.3) : 2.5);
	if (ipsa < 0) {
		ipsa = 0;       # daytime
	} elsif (ipsa > 1) {
		ipsa = 1.0000;  # nighttime
	}
	setprop("sim/model/material/instruments/factor", (1 - (ipsa * 0.4)));
}

#==========================================================================
# loop function #2 called by interior_lighting_loop every 3 seconds
#    or every 0.25 when time warp or every 0.05 during condition red lighting

var interior_lighting_update = func {
	var intli = 0;    # calculate brightness of interior lighting as sun goes down
	var intlir = 0;    # condition lighting tint for red emissions
	var intlig = 0;    # condition lighting tint for green and blue emissions
	sun_angle = getprop("sim/time/sun-angle-rad");  # Tied property, cannot listen
	if (power_switch) {
		if (int_switch) {
			intli = emis_calc;	# maximum emission always 0.7 at night
		}
		if (alert_switch or damage_count > 0) {
			var red_state = getprop("sim/model/danube/lighting/alert1/state");  # bring lighting up or down
			if (red_state) {
				alert_level += 0.08;
				if (alert_level > 1.0) {
					alert_level = 1.0;
				}
			} elsif (!red_state) {
				alert_level -= 0.08;
				if (alert_level < 0.25) {
					alert_level = 0.25;
				}
			}
			setprop("sim/model/danube/lighting/overhead/emission/red", alert_level * int_switch);  # set red brightness
			setprop("sim/model/danube/lighting/overhead/emission/gb", 0);
			intlir = intli * alert_level;  # adjust lighting accordingly
			intlig = intli * alert_level * 0.5;
			setprop("sim/model/danube/lighting/waldo/emission/red", (alert_level * 0.8 * int_switch));
			setprop("sim/model/danube/lighting/waldo/emission/gb", (alert_level * 0.4 * int_switch));
		} else {
			setprop("sim/model/danube/lighting/overhead/emission/red", int_switch);
			setprop("sim/model/danube/lighting/overhead/emission/gb", int_switch);
			setprop("sim/model/danube/lighting/waldo/emission/red", int_switch * 0.8);
			setprop("sim/model/danube/lighting/waldo/emission/gb", int_switch * 0.8);
			intlir = intli;
			intlig = intli;
		}
		# fade marker lighting when damaged
		setprop("sim/model/danube/lighting/interiorB-door-lights/emission/rgb", (1.0 - (damage_count * 0.25)));
	} else {
		setprop("sim/model/danube/lighting/interiorB-door-lights/emission/rgb", 0);
		setprop("sim/model/danube/lighting/overhead/emission/red", 0);
		setprop("sim/model/danube/lighting/overhead/emission/gb", 0);
		setprop("sim/model/danube/lighting/waldo/emission/red", 0);
		setprop("sim/model/danube/lighting/waldo/emission/gb", 0);
	}
	# Defaults 1 Off-White
		#  2 Reddish-tan_walls
		#  3 Silver
		#  4 MedLgt-Grey
		#  5 Beige
		#  6 Brown
		#  7 Lavender_rug
		#  8 Dk.Brown
		#  9 Lavender_Seats
		#  A WHITE_pad_floor
		#  B WHITE_door_marker_lights
		#  C GREY unlit ceiling
		#  D door_panel
	for (var i = 0; i < livery_cabin_count; i += 1) {
		set_ambient_I(i);  # calculate and set ambient levels
	}
	# next calculate emissions for night lighting
	if (trans_switch) {
		setprop("sim/model/danube/lighting/interiorA-transporter-lights/emission/red", 0.5 * power_switch);
		setprop("sim/model/danube/lighting/interiorA-transporter-lights/emission/gb", 0.5 * power_switch);
	} else {
		setprop("sim/model/danube/lighting/interiorA-transporter-lights/emission/red", 0.08 * intlir);
		setprop("sim/model/danube/lighting/interiorA-transporter-lights/emission/gb", 0.08 * intlig);
	}
	interior_lighting_base_R = intlir;
	for (var i = 0; i < livery_cabin_count; i += 1) {
		setprop("sim/model/danube/lighting/"~livery_cabin_surface[i].pname~"/emission/red", livery_cabin_surface[i].ER * intlir);
	}
	interior_lighting_base_GB = intlig;
	for (var i = 0; i < livery_cabin_count; i += 1) {
		if (livery_cabin_surface[i].type == "GB") {
			setprop("sim/model/danube/lighting/"~livery_cabin_surface[i].pname~"/emission/gb", livery_cabin_surface[i].EG * intlig);
		} else {
			setprop("sim/model/danube/lighting/"~livery_cabin_surface[i].pname~"/emission/green", livery_cabin_surface[i].EG * intlig);
			setprop("sim/model/danube/lighting/"~livery_cabin_surface[i].pname~"/emission/blue", livery_cabin_surface[i].EB * intlig);
		}
	}
	setprop("sim/model/danube/lighting/interior-specular", (0.5 - (0.5 * int_switch)));
	panel_lighting_update();
}

var interior_lighting_loop = func {
	interior_lighting_update();
	if (alert_switch) {
		settimer(interior_lighting_loop, 0.05);
	} else {
		if (getprop("sim/time/warp-delta")) {
			settimer(interior_lighting_loop, 0.25);
		} else {
			settimer(interior_lighting_loop, 3);
		}
	}
}

setlistener("sim/model/livery/material/interior-frame/ambient/red", func(n) {
	livery_cabin_surface[1].AR = n.getValue();
	recalc_material_I(1);
	set_ambient_I(1);
},, 0);

setlistener("sim/model/livery/material/interior-frame/ambient/green", func(n) {
	livery_cabin_surface[1].AG = n.getValue();
	recalc_material_I(1);
	set_ambient_I(1);
},, 0);

setlistener("sim/model/livery/material/interior-frame/ambient/blue", func(n) {
	livery_cabin_surface[1].AB = n.getValue();
	recalc_material_I(1);
	set_ambient_I(1);
},, 0);

setlistener("sim/model/livery/material/interior-walls1/ambient/red", func(n) {
	livery_cabin_surface[2].AR = n.getValue();
	recalc_material_I(2);
	set_ambient_I(2);
},, 0);

setlistener("sim/model/livery/material/interior-walls1/ambient/green", func(n) {
	livery_cabin_surface[2].AG = n.getValue();
	recalc_material_I(2);
	set_ambient_I(2);
},, 0);

setlistener("sim/model/livery/material/interior-walls1/ambient/blue", func(n) {
	livery_cabin_surface[2].AB = n.getValue();
	recalc_material_I(2);
	set_ambient_I(2);
},, 0);

setlistener("sim/model/livery/material/interior-ceiling-lower/ambient/red", func(n) {
	livery_cabin_surface[4].AR = n.getValue();
	recalc_material_I(4);
	set_ambient_I(4);
},, 0);

setlistener("sim/model/livery/material/interior-ceiling-lower/ambient/green", func(n) {
	livery_cabin_surface[4].AG = n.getValue();
	recalc_material_I(4);
	set_ambient_I(4);
},, 0);

setlistener("sim/model/livery/material/interior-ceiling-lower/ambient/blue", func(n) {
	livery_cabin_surface[4].AB = n.getValue();
	recalc_material_I(4);
	set_ambient_I(4);
},, 0);

setlistener("sim/model/livery/material/interior-walls2/ambient/red", func(n) {
	livery_cabin_surface[5].AR = n.getValue();
	recalc_material_I(5);
	set_ambient_I(5);
},, 0);

setlistener("sim/model/livery/material/interior-walls2/ambient/green", func(n) {
	livery_cabin_surface[5].AG = n.getValue();
	recalc_material_I(5);
	set_ambient_I(5);
},, 0);

setlistener("sim/model/livery/material/interior-walls2/ambient/blue", func(n) {
	livery_cabin_surface[5].AB = n.getValue();
	recalc_material_I(5);
	set_ambient_I(5);
},, 0);

setlistener("sim/model/livery/material/interior-flooring/ambient/red", func(n) {
	livery_cabin_surface[7].AR = n.getValue();
	recalc_material_I(7);
	set_ambient_I(7);
},, 0);

setlistener("sim/model/livery/material/interior-flooring/ambient/green", func(n) {
	livery_cabin_surface[7].AG = n.getValue();
	recalc_material_I(7);
	set_ambient_I(7);
},, 0);

setlistener("sim/model/livery/material/interior-flooring/ambient/blue", func(n) {
	livery_cabin_surface[7].AB = n.getValue();
	recalc_material_I(7);
	set_ambient_I(7);
},, 0);

setlistener("sim/model/livery/material/interior-seat-cover/ambient/red", func(n) {
	livery_cabin_surface[9].AR = n.getValue();
	recalc_material_I(9);
	set_ambient_I(9);
},, 0);

setlistener("sim/model/livery/material/interior-seat-cover/ambient/green", func(n) {
	livery_cabin_surface[9].AG = n.getValue();
	recalc_material_I(9);
	set_ambient_I(9);
},, 0);

setlistener("sim/model/livery/material/interior-seat-cover/ambient/blue", func(n) {
	livery_cabin_surface[9].AB = n.getValue();
	recalc_material_I(9);
	set_ambient_I(9);
},, 0);

setlistener("sim/model/livery/material/interior-door-panels/ambient/red", func(n) {
	livery_cabin_surface[10].AR = n.getValue();
	recalc_material_I(10);
	set_ambient_I(10);
},, 0);

setlistener("sim/model/livery/material/interior-door-panels/ambient/green", func(n) {
	livery_cabin_surface[10].AG = n.getValue();
	recalc_material_I(10);
	set_ambient_I(10);
},, 0);

setlistener("sim/model/livery/material/interior-door-panels/ambient/blue", func(n) {
	livery_cabin_surface[10].AB = n.getValue();
	recalc_material_I(10);
	set_ambient_I(10);
},, 0);

#==========================================================================
# loop function #3 called by nav_light_loop every 3 seconds
#    or every 0.5 seconds when time warp ============================

var nav_lighting_update = func {
	var nlu_nav = nav_light_switch.getValue();
	if (nlu_nav == 2) {
		nav_lights_state.setBoolValue(1);
	} else {
		if (nlu_nav == 1) {
			nav_lights_state.setBoolValue(visibility < 5000 or sun_angle > 1.4);
		} else {
			nav_lights_state.setBoolValue(0);
		}
	}
	# window shading factor between 0 transparent and 1 opaque
	#      if lights on   range(0.3-0.7) midnight to noon
	#    else lights off  range(0.6-1.0)
	if (!getprop("sim/model/cockpit-visible")) {
		var wsv = 1.0;
	} else {
		var wsv = -9999;
		if (visibility < 5000 or sun_angle > 1.2) {  # dawn/dusk bright side
			if (int_switch) {      # lights on
				# dawn/dusk darkest : dark night
				wsv = (sun_angle < 2.0 ? (1.3 - (sun_angle * 0.5)) : 0.3);
			} else {            # lights off
				wsv = (sun_angle < 2.0 ? (1.6 - (sun_angle * 0.5)) : 0.6);
			}
		} else {      # daytime
			wsv = (int_switch ? 0.7 : 1.0);
		}
	}
	setprop("sim/model/danube/lighting/window-factor", wsv);
}

var nav_light_loop = func {
	nav_lighting_update();
	if (getprop("sim/time/warp-delta")) {
		settimer(nav_light_loop, 0.5);
	} else {
		settimer(nav_light_loop, 3);
	}
}

#==========================================================================

var change_maximum = func(cm_from, cm_to, cm_type) {
	var lmt = limit[(impulse_level + (warp1_level* 2) + (warp2_level* 4))] - damage_count ;
	if (lmt < 0) {
		lmt = 0;
	}
	if (cm_to < 0) {  # shutdown by crash
		cm_to = 0;
	}
	if (max_drift) {   # did not finish last request yet
		if (cm_to > cm_from) {
			if (cm_type < 2) {  # startup from power down. bring systems back online
				cm_to = max_to + 1;
			}
		} else {
			var cm_to_new = max_to - 1;
			if (cm_to_new < 0) {  # midair shutdown
				cm_to_new = 0;
			}
			cm_to = cm_to_new;
		}
		if (cm_to >= size(speed_mps)) { 
			cm_to = size(speed_mps) - 1;
		}
		if (cm_to >= lmt) {
			cm_to = lmt;
		}
		if (cm_to < 0) {
			cm_to = 0;
		}
	} else {
		max_from = cm_from;
	}
	max_to = cm_to;
	max_drift = abs(speed_mps[cm_from] - speed_mps[cm_to]) / 20;
	if (cm_type > 1) {
		# separate new maximum from limit. by engine shutdown/startup
		current_to = cpl;
	} else { 
		# by joystick flaps request
		current_to = cm_to;
	}
}

# modify flaps to change maximum speed --------------------------

controls.flapsDown = func(fd_d) {  # 1 decrease speed gearing -1 increases by default
	var fd_return = 0;
	if(power_switch) {
		if (!fd_d) {
			return;
		} elsif (fd_d > 0 and cpl > 0) {    # reverse joystick buttons direction by exchanging < for >
			change_maximum(cpl, (cpl-1), 1);
			fd_return = 1;
		} elsif (fd_d < 0 and cpl < size(speed_mps) - 1) {    # reverse joystick buttons direction by exchanging < for >
			var check_max = cpl;
			if (max_drift > 0) {
				check_max = max_to;
			}
			if (cpl >= limit[(impulse_level + (warp1_level* 2) + (warp2_level* 4))]) {
				if (warp1_level) {
					if (impulse_level) {
						popupTip2("Unable to comply. Orbital velocities requires higher energy setting");
					} else {
						popupTip2("Unable to comply. Requested velocity requires fusion reactor to be online");
					}
				} else {
					popupTip2("Unable to comply. Primary warp engine OFF LINE");
				}
			} elsif (check_max > 6 and contact_altitude < 15000) {
				popupTip2("Unable to comply below 15,000 ft.");
			} elsif (check_max > 7 and contact_altitude < 50000) {
				popupTip2("Unable to comply below 50,000 ft.");
			} elsif (check_max > 8 and contact_altitude < 328000) {
				popupTip2("Unable to comply below 328,000 ft. (100 Km) The boundary between atmosphere and space.");
			} elsif (check_max > 9 and contact_altitude < 792000) {
				popupTip2("Unable to comply below 792,000 ft. (150 Miles) The NASA defined boundary for space.");
			} else {
				change_maximum(cpl, (cpl + 1), 1);
				fd_return = 1;
			}
		}
		if (fd_return) {
			var ss = speed_mps[max_to];
			popupTip2("Max. Speed " ~ ss ~ " m/s");
		}
		current.setValue(cpl);
	} else {
		popupTip2("Unable to comply. Main power is off.");
	}
}


# position adjustment function =====================================

var reset_impact = func {
	damage_blocker = 0;
}

var settle_to_level = func {
	var hg_roll = roll_deg.getValue() * 0.75;
	roll_deg.setValue(hg_roll);  # unless on hill... doesn't work right with ufo model
	var hg_roll = roll_control.getValue() * 0.75;
	roll_control.setValue(hg_roll);
	var hg_pitch = pitch_deg.getValue() * 0.75;
	pitch_deg.setValue(hg_pitch);
	var hg_pitch = pitch_control.getValue() * 0.75;
	pitch_control.setValue(hg_pitch);
}

var check_damage = func (dmg_add) {
	var dmg = getprop("sim/model/danube/damage/hits-counter") + dmg_add;
	setprop("sim/model/danube/damage/hits-counter", int(dmg));
	if (dmg > destruction_threshold) { 
		# set red-alert damage
		alert_switch_Node.setBoolValue(1);
		if (damage_blocker == 0) {
			damage_blocker = 1;
			damage_count += 1;
			settimer(reset_impact, 2);
			setprop("sim/model/danube/position/crash-wow", 1);
			settimer(reset_crash, 5);
			setprop("sim/model/danube/lighting/transporter-overhead", 0);
			setprop("sim/model/danube/damage/major-counter", damage_count);
			strobe_switch.setValue(0);
			zNoseNode.setValue(1.14);
			setprop("sim/model/danube/systems/nacelle-L-venting", 1);
			setprop("sim/model/danube/systems/nacelle-R-venting", 1);
			setprop("autopilot/locks/altitude", "");
			setprop("autopilot/locks/heading", "");
			set_cockpit(cockpitView);
			interior_lighting_update();
			if (int(100 * rand()) > 70 or dmg > (destruction_threshold * 1.5)) {  # 30% chance a nacelle is destroyed
				setprop("sim/model/danube/components/nacelle-L-detached", 1);
				if (int(100 * rand()) > 90 or dmg > (destruction_threshold * 2)) {  # how likely both were
					setprop("sim/model/danube/components/nacelle-R-detached", 1);
					setprop("sim/model/danube/components/module1-detached", 1);
				}
			} elsif (dmg > (destruction_threshold * 0.7)) {
				setprop("ai/submodels/pylon-L-flaring", 1);
			}
		}
	}
}

#==========================================================================
# -------- MAIN LOOP called by itself every cycle --------

var update_main = func {
	var gnd_elev = ground_elevation_ft.getValue();  # ground elevation
	var altitude = altitude_ft_Node.getValue();  # aircraft altitude

	if (gnd_elev == nil) {    # startup check
		gnd_elev = 0;
	}
	if (altitude == nil) {
		altitude = -9999;
	}
	if (altitude > -9990) {   # wait until program has started
		pitch_d = pitch_deg.getValue();   # update variables used by everybody
		airspeed = airspeed_kt_Node.getValue();
		asas = abs(airspeed);
		abs_airspeed_Node.setDoubleValue(asas);
		# ----- initialization checks -----
		if (init_agl > 0) {
			# trigger rumble sound to be on
			setprop("controls/engines/engine/throttle",0.01);
			# find real ground level
			altitude = gnd_elev + init_agl;
			altitude_ft_Node.setDoubleValue(altitude);
			if (init_agl > 1) {
				init_agl -= 0.75;
			} elsif (init_agl > 0.25) {
				init_agl -= 0.25;
			} else {
				init_agl -= 0.05;
			}
			if (init_agl <= 0) {
				setprop("controls/engines/engine/throttle",0);
			}
		}
		var hover_ft = 0;
		contact_altitude = altitude - vertical_offset_ft - hover_add;   # adjust calculated altitude for nacelle/nose dip
		# ----- only check hover if near ground ------------------
		var new_ground_near = 0;   # see if indicator lights can be turned off
		var new_ground_warning = 0;
		var check_agl = (asas * 0.05) + 40;
		if (check_agl < 50) {
			check_agl = 50;
		}
		if (contact_altitude < (gnd_elev + check_agl)) {
			new_ground_near = 1;
			var rolld = abs(roll_deg.getValue()) / 2.9;
			var skid_w2 = 0;
			var skid_altitude_change = 0;
			if (pitch_d > 0) {
				if (pitch_d > 74) {  # try to keep rear of nacelles from touching ground
					hover_add = 29.6;
				} else {
					hover_add = pitch_d / 2.5;
				}
			} else {
				if (pitch_d < -44) {  # try to keep nose from touching ground
					hover_add = abs((pitch_d + 44) / 1.9) + 33.8;
				} else {
					hover_add = abs(pitch_d / 1.3);
				}
			}
			if (rolld > 23.0) {  # keep nacelles from touching ground
				rolld = 23.0;
			}
			hover_add = hover_add + rolld;   # total clearance for model above gnd_elev
			# add to hover the airspeed calculation to increase ground separation with airspeed
			if (asas < 100) {  # near ground hovering altitude calculation
				hover_ft = 2.3 + (0.022 * (asas - 100));
			} elsif (asas > 500) {  # increase separation from ground
				hover_ft = 22.3 + ((asas - 500) * 0.023);
			} else {    # hold altitude above ground, increasing with velocity
				hover_ft = (asas * 0.05) - 2.7;
			}
			if (engines_lvl < 1.0) {
				hover_ft = (hover_ft * engines_lvl);  # smoothen assent on startup
			}

			if (gnd_elev < 0) {
				# likely over ocean water
				gnd_elev = 0;  # keep above water until there is an ocean bottom
			}
			contact_altitude = altitude - vertical_offset_ft - hover_add;   # update with newer hover amounts
			hover_target_altitude = gnd_elev + vertical_offset_ft + hover_add + hover_ft;  # hover elevation
			h_contact_target_alt = gnd_elev + hover_ft;

			if (contact_altitude < h_contact_target_alt) {
				# below ground/flight level
				if (altitude > 0) {            # check for skid, smoothen sound effects
					if (contact_altitude < gnd_elev) {
						skid_w2 = (gnd_elev - contact_altitude);  # depth
						if (skid_w2 < skid_last_value) {  # abrupt impact or
							# below ground, contact should skid
							skid_w2 = (skid_w2 + skid_last_value) * 0.75; # smoothen ascent
						}
					}
				}
				skid_altitude_change = hover_target_altitude - altitude;
				if (skid_altitude_change > 0.5) {
					new_ground_warning = 1;
					if (skid_altitude_change < hover_ft) {
						# hover increasing altitude, but still above ground
						# add just enough skid to create the sound of 
						# emergency anti-grav and thruster action
						if (skid_w2 < 1.0) {
							skid_w2 = 1.0;
						}
					}
					if (skid_altitude_change > skid_w2) {
						# keep skid sound going and dig in if bounding up large hill
						var impact_factor = (skid_altitude_change / asas * 25);
						# vulnerability to impact. Increasing from 25 increases vulnerability
						if (skid_altitude_change > impact_factor) {  # but not if on flat ground
							new_ground_warning = 2;
							skid_w2 = skid_altitude_change;  # choose the larger skid value
						}
					}
				}
				if (hover_ft < 0) {  # separate skid effects from actual impact
					altitude = hover_target_altitude - hover_ft;
				} else {
					altitude = hover_target_altitude;
				}
				altitude_ft_Node.setDoubleValue(altitude);  # force above ground elev to hover elevation at contact
				contact_altitude = altitude - vertical_offset_ft - hover_add;
				if (pitch_d > 0 or pitch_d < -0.5) {
					# If aircraft hits ground, then nose/tail gets thrown up
					if (asas > 500) {  # new pitch adjusted for airspeed
						var airspeed_pch = 0.2;  # rough ride
					} else {
						var airspeed_pch = asas / 500 * 0.2;
					}
					if (airspeed > 0.1) {
						if (pitch_d > 0) {
							# going uphill
							pitch_d = pitch_d * (1.0 + airspeed_pch);
							pitch_deg.setDoubleValue(pitch_d);
						} else {
							# nose down
							pitch_d = pitch_d * (1.0 - airspeed_pch);
							pitch_deg.setDoubleValue(pitch_d);
						}
					} elsif (airspeed < -0.1) {    # reverse direction
						if (pitch_d < 0) {  # uphill
							pitch_d = pitch_d * (1.0 + airspeed_pch);
							pitch_deg.setDoubleValue(pitch_d);
						} else {
							pitch_d = pitch_d * (1.0 - airspeed_pch);
							pitch_deg.setDoubleValue(pitch_d);
						}
					}
				}
			} else {
				# smoothen to zero
				var skid_w2 = (skid_last_value) / 2;
			}
			if (skid_w2 < 0.001) {
				skid_w2 = 0;
			}
			# threshold for determining a damage Hit
			if (skid_w2 > 10 and asas > 100) {
				# impact greater than 600 feet per second
				ignite();
				var dmg_factor = int(skid_w2 * 0.025 * (abs(pitch_d) * 0.011) + 1.0);  # vulnerability to impact
				# increasing number from 0.025 ^^^^^ increases damage per hit
				if (dmg_factor < 1) {  # if impact, then at least one damage unit
					dmg_factor = 1;
				} else {
					var angle_of_damage_max = ((abs(pitch_d) * 0.67) + 30);
					if (dmg_factor > angle_of_damage_max) {  # maximum damage per major impact
						dmg_factor = angle_of_damage_max;
					}
				}
				check_damage(dmg_factor);
			}
			var skid_w_vol = skid_w2 * 0.1;  # factor for volume usage
			if (skid_w_vol > 1.0) {
				skid_w_vol = 1.0;
			}
			if (!damage_count and (skid_altitude_change < 5)) {
				if (abs(pitch_d) < 3.75) {
					skid_w_vol = skid_w_vol * (abs(pitch_d + 0.25)) * 0.25;
				}
			}
			setprop("sim/model/danube/position/skid-wow", skid_w_vol);
			skid_last_value = skid_w2;
		} else { 
			# not near ground, skipping hover
			setprop("sim/model/danube/position/skid-wow", 0);
			skid_last_value = 0;
			hover_add = 0;
			h_contact_target_alt = 0;
		}
		# update instrument warning lights if changed
		if (new_ground_near != ground_near) {
			if (new_ground_near) {
				setprop("sim/model/danube/lighting/ground-near", 1);
			} else {
				setprop("sim/model/danube/lighting/ground-near", 0);
			}
			ground_near = new_ground_near;
		}
		if (new_ground_warning != ground_warning) {
			setprop("sim/model/danube/lighting/ground-warning", new_ground_warning);
			ground_warning = new_ground_warning;
		}

		# ----- lose altitude -----
		if (damage_count > 0 or engines_lvl < 0.2 or power_switch == 0) {
			if ((contact_altitude - 0.0001) < h_contact_target_alt) {
				# already on/near ground
				if (lose_altitude > 0.2) {
					lose_altitude = 0.2;  # avoid bouncing by simulating gravity
				}
				if (!antigrav.request) {
					if (!impulse_request) {
						settle_to_level();
					}
				} else {
					lose_altitude = 0;
				}
			} else {
				# not on/near ground
				if (!(warp1_level and asas > 150)) {
					# warp power is off and not fast enough to fly without engines on-line
					lose_altitude += 0.01;
	# need to adjust terminal velocity based on pitch and add actual physics
					if (lose_altitude > 17) {
						# maximum at terminal velocity with nose down unpowered estimated: 1026ft/sec
						lose_altitude = 17;
					}
					if ((contact_altitude - h_contact_target_alt) < 3) {   # really close to ground but not below it
						if (!impulse_request) {
							settle_to_level();
						}
					}
				} else { # fast enough to fly without anti-grav
					lose_altitude = lose_altitude * 0.5;
					if (lose_altitude < 0.001) {
						lose_altitude = 0;
					}
				}
			}
			if (lose_altitude > 0) {
				up(-1, lose_altitude, 0);
			}
		} else {
			lose_altitude = 0;
		}

		# ----- also calculate altitude-agl since ufo model doesn't -----
		var aa = altitude - gnd_elev;
		setprop("sim/model/danube/position/shadow-alt-agl-ft", aa);
		var agl = contact_altitude - gnd_elev + hover_add;
		setprop("sim/model/danube/position/altitude-agl-ft", agl);

		# ----- handle traveling backwards and update movement variables ------
		#       including updating sound based on airspeed
		# === speed up or slow down from engine level ===
		var max = maxspeed.getValue();
		if ((damage_count > 0) or
			(nacelleL_detached and warp1_request > 0) or 
			(nacelleR_detached and warp1_request > 0) or
			(!power_switch)) { 
			if (warp1_request) {   # deny warp drive request
				setprop("sim/model/danube/systems/warp1-request", 0);
				warp1_request = 0;
			}
			if (warp2_request) {
				setprop("sim/model/danube/systems/warp2-request", 0);
				warp2_request = 0;
			}
			if (damage_count > 2) {
				setprop("sim/model/danube/systems/impulse-request", 0);
				impulse_request = 0;
				setprop("sim/model/danube/systems/power-switch", 0);
				if (shutdown_venting == 0) {	# turn off extra particles after 1 minute
					shutdown_venting = 1;
					settimer(func {
						setprop("sim/model/danube/systems/nacelle-L-venting", 0);
						setprop("sim/model/danube/systems/nacelle-R-venting", 0);
						update_venting(1,0);
						}, 60, 1);
				}
			}
		}
		if (cpl > 6) {
			if (cpl > 10 and contact_altitude < 792000 and max_to > 10) {
				popupTip2("Approaching planet. Reducing speed");
				change_maximum(cpl, 10, 1); 
			} elsif (cpl > 9 and contact_altitude < 328000 and max_to > 9) {
				popupTip2("Entering upper atmosphere. Reducing speed");
				change_maximum(cpl, 9, 1); 
			} elsif (cpl > 8 and contact_altitude < 50000 and max_to > 8) {
				popupTip2("Entering lower atmosphere. Reducing speed");
				change_maximum(cpl, 8, 1); 
			} elsif (cpl > 7 and contact_altitude < 15000 and max_to > 7) {
				popupTip2("Entering lower atmosphere. Reducing speed");
				change_maximum(cpl, 7, 1); 
			}
		}
		if (!power_switch) {
			change_maximum(cpl, 0, 2);
			if (warp1_level) {
				setprop("sim/model/danube/systems/warp1-level", 0);
			}
			if (warp2_level) {
				warp2_level = 0;
			}
			if (agl > 10) {   # not in ground contact, glide
				max_lose = max_lose + (0.005 * abs(pitch_d));
			} else {     # rapid deceleration
				max_lose = (asas < 80 ? (asas > 20 ? 16 : ((100 - asas) * asas * 0.01)) : (asas * 0.2));
			}
	# need to import acceleration physics calculations from walker
			if (max_lose > 10) {  # don't decelerate too quickly
				if (agl > 10) {
					max_lose = 10;
				} else {
					if (max_lose > 75) {
						max_lose = 75;
					}
				}
			}
			if (asas < 5) {  # already stopped
				maxspeed.setDoubleValue(0);
				setprop("controls/engines/engine/throttle", 0.0);
			}
			max_drift = max_lose;
		} else {  # power is on
			if (impulse_request != impulse_level) {
				change_maximum(cpl, limit[(impulse_request + (warp1_level * 2) + (warp2_level * 4))] - damage_count, 2);
				setprop("sim/model/danube/systems/impulse-level", impulse_request);
			}
			if (warp1_request != warp1_level) {
				change_maximum(cpl, limit[(impulse_level + (warp1_request * 2) + (warp2_level * 4))] - damage_count, 2);
				setprop("sim/model/danube/systems/warp1-level", warp1_request);
			}
			if (warp2_request != warp2_level) {
				change_maximum(cpl, limit[(impulse_level + (warp1_level * 2) + (warp2_request * 4))] - damage_count, 2);
				warp2_level = warp2_request;
				setprop("sim/model/danube/systems/warp2-level", warp2_level);
			}
		}
		if (max > 1 and max_to < max_from) {      # decelerate smoothly
			max -= (max_drift / 2);
			if (max <= speed_mps[max_to]) {     # destination reached
				cpl = max_to;
				max_from = max_to;
				max = speed_mps[max_to];
				max_drift = 0;
				max_lose = 0;
				if (!power_switch) {       # override if no power
					max = 1;
				}
			}
			maxspeed.setDoubleValue(max);
		}
		if (max_to > max_from) {         # accelerate
			if (current_to == max_to) {   # normal request to change power-maxspeed
				max += max_drift;
				if (max >= speed_mps[max_to]) { 
					# destination reached
					cpl = max_to;
					max_from = max_to;
					max = speed_mps[max_to];
					max_drift = 0;
					max_lose = 0;
				}
				maxspeed.setDoubleValue(max);
			} else {    # only change maximum, as when turning on an engine
				max_from = max_to;
				max_drift = 0;
				max_lose = 0;
				if (cpl == 0 and current_to == 0) {     # turned on power from a complete shutdown
					maxspeed.setDoubleValue(speed_mps[2]);
					current_to = max_to;
					cpl = 2;
				}
			}
		}
		current.setValue(cpl);

		# === sound section based on position/airspeed/altitude ===
		var slv = sound_level;
		if (power_switch) {
			if (impulse_drift < 1 and slv > 1) {  # shutdown reactor before timer shutdown of standby power
				slv = 0.99;
			}
			if (asas < 1 and agl < 2 and !antigrav.request) {
				if (sound_state and slv > 0.999) {  # shutdown request by landing has 2.5 sec delay
					slv = 2.5;
				}
				sound_state = 0;
			} else {
				if (((impulse_state < impulse_drift) or (!impulse_state)) and asas < 5 and !antigrav.request) {  # antigrav shutdown
					sound_state = 0;
					antigrav.request = 0;
					if (antigrav.momentum_watch) {
						antigrav.up_factor = 0;
						antigrav.momentum_watch -= 1;
					}
					if (slv >= 1) {
						slv = 0.99;
					}
				} else {
					if (asas > 5 or agl >= 2 or antigrav.request) {
						sound_state = 1;
					} else {
						sound_state = 0;
					}
				}
			}
		} else {
			if (sound_state) {  # power shutdown with reactor on. single entry.
				slv = 0.99;
				sound_state = 0;
				antigrav.request = 0;
			}
		}
		if (sound_state != slv) {  # ramp up reactor sound fast or down slow
			if (sound_state) { 
				slv += 0.02;
			} else {
				slv -= 0.00625;
			}
			if (sound_state and slv > 1.0) {  # bounds check
				slv = 1.000;
				antigrav.request = 0;
			}
			if (slv > 0.5 and antigrav.request) {
				if (antigrav.request <= 1) {
					antigrav.request -= 0.025;  # reached sufficient power to turn off trigger
					slv -= 0.02;  # hold this level for a couple seconds until either another
					# keyboard/joystick request confirms startup, or time expires and shutdown
					if (antigrav.request < 0.1) {
						antigrav.request = 0;  # holding time expired
					}
				}
			}
			if (slv < 0.0) {
				slv = 0.000;
			}
			sound_level = slv;
		}
		# engine rumble sound
		if (asas < 200) {
			var a1 = 0.1 + (asas * 0.002);
		} elsif (asas < 4000) {
			var a1 = 0.5 + ((asas - 200) * 0.0001315);
		} else {
			var a1 = 1.0;
		}
		var a3 = (asas * 0.000187) + 0.25;
		if (a3 > 0.75) {
			a3 = ((asas - 4000) / 384000) + 0.75;
		}
		if (slv > 1.0) {    # timer to shutdown
			var a2 = a1;
			var a5 = (asas * 0.0002) + 0.4;
			var a6 = 1;
		} else {      # shutdown progressing
			var a2 = a1 * slv;
			a3 = a3 * slv;
			var a5 = 0.2 + (slv * ((asas * 0.0002) + 0.2));
			var a6 = slv;
		}
		a5 = clamp(a5, 0, 1);
		if (warp1_level) {
			setprop("sim/model/danube/lighting/bussard-glow-red", a5);
			setprop("sim/model/danube/lighting/bussard-glow-blgr", (0.1 - (a5 * 0.1)));
			if (asas > 1 or slv == 1.0 or slv > 2.0) {
				warp_state = (asas * 0.00032) + 0.4;
			} elsif (slv > 1.667) {
				warp_state = ((slv * 3) - 5) * ((asas * 0.00032) + 0.4);
			} else {
				warp_state = 0;
			}
		} else {
			setprop("sim/model/danube/lighting/bussard-glow-red", 0.2);
			setprop("sim/model/danube/lighting/bussard-glow-blgr", 0.1);
			warp_state = 0;
		}
		if (impulse_level) {
			if (damage_count) {
				impulse_state = a6 * 0.5;
			} else {
				impulse_state = a6;
			}
		} else {
			impulse_state = 0;
		}
		if (power_switch) {
			if (impulse_state > impulse_drift) {
				impulse_drift += 0.04;
				if (impulse_drift > impulse_state) {
					impulse_drift = impulse_state;
				}
			} elsif (impulse_state < impulse_drift) {
				if (impulse_level) {
					impulse_drift = impulse_state;
				} else {
					impulse_drift -= 0.02;
				}
			}
		} else {
			impulse_drift -= 0.02;
		}
		if (impulse_drift < 0) {  # bounds check
			impulse_drift = 0;
		}
		if (warp_state > warp_drift) {
			warp_drift += 0.1;
			if (warp_drift > warp_state) {
				warp_drift = warp_state;
			}
		} elsif (warp_state < warp_drift) {
			if (warp1_level) {
				warp_drift -= 0.1;
			} else {
				warp_drift -= 0.02;
			}
			if (warp_drift < warp_state) {
				warp_drift = warp_state;
			}
		}
		var a4 = warp_drift;
		if (!impulse_level and !warp1_level) {
			a2 = a2 / 2;
		}
		if (a3 > 12.5) {  # set upper limits
			a3 = 12.5;
		}
		if (a4 > 1.75) {
			a4 = 1.75;
		}
		setprop("sim/model/danube/sound/engines-volume-level", a2);
		setprop("sim/model/danube/sound/pitch-level", a3);
		setprop("sim/model/danube/lighting/engine-glow", impulse_drift);
		if (impulse_level) {
			if (!impulse_drift and !power_switch and !slv) {
				setprop("sim/model/danube/systems/impulse-level", 0);
			}
		}
		setprop("sim/model/danube/lighting/warp-glow", a4);

		# nacelle venting
		if (venting_direction >= -1) {
			update_venting(0,0);
		}
	}
	settimer(update_main, 0);
}

# VTOL anti-grav functions ---------------------------------------

controls.elevatorTrim = func(et_d) {
	if (!et_d) {
		return;
	} else {
		antigrav.input_type = 2;
		var js1pitch = abs(joystick_elevator.getValue());
		up((et_d < 0 ? -1 : 1), js1pitch, 2);
	}
}

var reset_landing = func {
	setprop("sim/model/danube/position/landing-wow", 0);
}

setlistener("sim/model/danube/position/landing-wow", func(n) {
	if (n.getValue()) {
		settimer(reset_landing, 0.4);
		if (antigrav.momentum) {
			antigrav.up_factor = 0;
			antigrav.momentum_watch -= 1;
			antigrav.momentum = 0;
		}
	}
},, 0);

var reset_squeal = func {
	setprop("sim/model/danube/position/squeal-wow", 0);
}

setlistener("sim/model/danube/position/squeal-wow", func(n) {
	if (n.getValue()) {
		settimer(reset_squeal, 0.3);
	}
},, 0);

var reset_crash = func {
	setprop("sim/model/danube/position/crash-wow", 0);
}

# mouse hover -------------------------------------------------------
#var KbdShift = props.globals.getNode("/devices/status/keyboard/shift");
#var KbdCtrl = props.globals.getNode("/devices/status/keyboard/ctrl");
var mouse = { savex: nil, savey: nil };
setlistener("/sim/startup/xsize", func(n) mouse.centerx = int(n.getValue() / 2), 1);
setlistener("/sim/startup/ysize", func(n) mouse.centery = int(n.getValue() / 2), 1);
setlistener("/sim/mouse/hide-cursor", func(n) mouse.hide = n.getValue(), 1);
#setlistener("/devices/status/mice/mouse/x", func(n) mouse.x = n.getValue(), 1);
setlistener("/devices/status/mice/mouse/y", func(n) mouse.y = n.getValue(), 1);
setlistener("/devices/status/mice/mouse/mode", func(n) mouse.mode = n.getValue(), 1);
setlistener("/devices/status/mice/mouse/button[0]", func(n) mouse.lmb = n.getValue(), 1);
setlistener("/devices/status/mice/mouse/button[1]", func(n) {
	mouse.mmb = n.getValue();
	if (mouse.mode)
		return;
	if (mouse.mmb) {
		controls.centerFlightControls();
#		mouse.savex = mouse.x;
		mouse.savey = mouse.y;
		gui.setCursor(mouse.centerx, mouse.centery, "none");
	} else {
		gui.setCursor(mouse.savex, mouse.savey, "pointer");
		antigrav.up_factor = 0;
		if (antigrav.momentum_watch > 0) {
			antigrav.momentum_watch -= 1;
		}
	}
}, 1);
setlistener("/devices/status/mice/mouse/button[2]", func(n) {
	mouse.rmb = n.getValue();
	if (antigrav.momentum_watch) {
		antigrav.up_factor = 0;
		antigrav.momentum_watch -= 1;
	}
}, 1);


mouse.loop = func {
	if (mouse.mode or !mouse.mmb) {
		return settimer(mouse.loop, 0);
	}
#	var dx = mouse.x - mouse.centerx;
	var dy = -mouse.y + mouse.centery;
	if (dy) {
		antigrav.input_type = 3;
		antigrav.up_factor = dy * 0.001;
		if (antigrav.momentum_watch < 1) {
			antigrav.momentum_watch = 3;
			coast_up(coast_loop_id += 1);
		}
		gui.setCursor(mouse.centerx, mouse.centery);
	}
	settimer(mouse.loop, 0);
}
mouse.loop();

# keyboard hover ----------------------------------------------------
setlistener("sim/model/danube/hover/key-up", func(n) {
	var key_dir = n.getValue();
	if (key_dir) {	# repetitive input or lack of older mod-up may keep triggering
		antigrav.input_type = 1;
		antigrav.up_factor = (key_dir < 0 ? -0.01 : 0.01);
		if (antigrav.momentum_watch <= 0) {
			antigrav.momentum_watch = 3;	# start or reset timer for countdown
			coast_up(coast_loop_id += 1);	# starting from rest, start new loop
		} else {
			antigrav.momentum_watch = 3;	# reset watcher
		}
	} else {
		antigrav.momentum_watch -= 1;
		antigrav.up_factor = 0;
		if (antigrav.momentum_watch < 0) {
			antigrav.momentum_watch = 0;
		}
	}
});

var coast_loop_id = 0;
var coast_up = func (id) {
	id == coast_loop_id or return;
	if (antigrav.momentum_watch >= 3) {
		antigrav.momentum += antigrav.up_factor;
		if (antigrav.input_type == 3) {
			antigrav.up_factor = 0;
		}
		if (abs(antigrav.momentum) > 2.0) {
			antigrav.momentum = (antigrav.momentum < 0 ? -2.0 : 2.0);
		}
	} elsif (antigrav.momentum_watch >= 2) {
		antigrav.momentum_watch -= 1;
	} else {
		antigrav.momentum = antigrav.momentum * 0.75;
		if (abs(antigrav.momentum) < 0.02) {
			antigrav.momentum = 0;
			antigrav.momentum_watch = 0;
		}
	}
	if (antigrav.momentum) {
		up((antigrav.momentum < 0 ? -1 : 1), antigrav.momentum, antigrav.input_type);
	}
	if (antigrav.momentum_watch) {
		settimer(func { coast_up(coast_loop_id += 1) }, 0);
	} else {
		antigrav.momentum = 0;
	}
}

var up = func(hg_dir, hg_thrust, hg_mode) {  # d=direction p=thrust_power m=source of request
	var entry_altitude = altitude_ft_Node.getValue();
	var altitude = entry_altitude;
	contact_altitude = altitude - vertical_offset_ft - hover_add;
	if (hg_mode == 1 or hg_mode == 3) {
		# 1 = keyboard , 3 = mouse
		var hg_rise = antigrav.momentum * 4;
	} else {
		# 0 = gravity , 2 = joystick
		var hg_rise = hg_thrust * 4 * hg_dir;
	}
	var contact_rise = contact_altitude + hg_rise;
	if (hg_dir < 0) {    # down requested by drift, fall, or VTOL down buttons
		if (contact_rise < h_contact_target_alt) {  # too low
			contact_rise = h_contact_target_alt + 0.0001;
			if ((contact_rise < contact_altitude) and !antigrav.request) {
				if (asas < 40) {  # ground contact by landing or falling fast
					if (lose_altitude > 0.2 or hg_rise < -0.5) {
						var already_landed = getprop("sim/model/danube/position/landing-wow");
						if (!already_landed) {
							setprop("sim/model/danube/position/landing-wow", 1);
						}
						check_damage(lose_altitude * 5);
						lose_altitude = 0;
						if (!impulse_request) {
							settle_to_level();
						}
					} else {
						lose_altitude = lose_altitude * 0.5;
					}
				} elsif (lose_altitude > 0.26 and hg_rise < -1.1) {  # ground contact by skidding slowly
					setprop("sim/model/danube/position/squeal-wow", 1);
						lose_altitude = lose_altitude * 0.5;
					check_damage(lose_altitude);
					if (!impulse_request) {
						settle_to_level();
					}
				}
			} else {
				lose_altitude = lose_altitude * 0.5;
			}
		}
		if (!antigrav.request) {  # fall unless antigrav just requested
			altitude = contact_rise + vertical_offset_ft + hover_add;
			altitude_ft_Node.setDoubleValue(altitude);
			contact_altitude = contact_rise;
		}
	} elsif (hg_dir > 0) {  # up
		if (engines_lvl < 0.5 and impulse_level) {  # on standby, power up requested for hover up
			if (power_switch) {
				setprop("sim/model/danube/systems/impulse-request", 1);
				antigrav.request += 1;   # keep from forgetting until reactor powers up over 0.5
				antigrav.momentum = 0;
			}
		}
		if (engines_lvl > 0.2 and impulse_level) {  # sufficient power to comply and lift
			contact_rise = contact_altitude + (engines_lvl * hg_rise);
			altitude = contact_rise + vertical_offset_ft + hover_add;
			altitude_ft_Node.setDoubleValue(altitude);
			contact_altitude = contact_rise;
		}
	}
	if ((entry_altitude + hg_rise + 0.01) < altitude) {  # did not achieve full request. must've touched ground
		if (lose_altitude > 0.2) {
			lose_altitude = 0.2;
		}
	}
}

# keyboard and 3-d functions ----------------------------------------

var toggle_power = func(tp_mode) {
	if (tp_mode == 9) {  # clicked from dialog box
		if (!power_switch) {
			setprop("sim/model/danube/systems/impulse-request", 0);
			setprop("sim/model/danube/systems/warp1-request", 0);
			change_maximum(cpl, 0, 2);
		}
	} elsif (tp_mode == 4) {  # clicked LCARS panel
		var tp_panel = getprop("sim/model/danube/lighting/LCARS-panel");
		if (tp_panel and power_switch) {
			setprop("sim/model/danube/lighting/LCARS-panel", 0);
		} else {
			setprop("sim/model/danube/systems/power-switch", 1);
			setprop("sim/model/danube/lighting/LCARS-panel", 1);
		}
	} else {   # clicked from 3d-panel or keyboard
		if (power_switch) {
			if (!getprop("sim/model/danube/lighting/LCARS-panel") and tp_mode == 2) {
				setprop("sim/model/danube/lighting/LCARS-panel", 1);
			} else {
				setprop("sim/model/danube/systems/power-switch", 0);
				setprop("sim/model/danube/systems/impulse-request", 0);
				setprop("sim/model/danube/systems/warp1-request", 0);
				setprop("sim/model/danube/lighting/LCARS-panel", 0);
				change_maximum(cpl, 0, 2);
			}
		} else {
			setprop("sim/model/danube/systems/power-switch", 1);
			setprop("sim/model/danube/lighting/LCARS-panel", 1);
		}
	}
	interior_lighting_update();
	danube.reloadDialog1();
}

var toggle_impulse = func {
	if (impulse_request) {
		setprop("sim/model/danube/systems/impulse-request", 0);
	} else {
		if (power_switch) {
			setprop("sim/model/danube/systems/impulse-request", 1);
		} else {
			popupTip2("Unable to comply. Main power is off.");
		}
	}
	danube.reloadDialog1();
}

var toggle_warp1 = func {
	if (warp1_request) {
		setprop("sim/model/danube/systems/warp1-request", 0);
	} else {
		if (power_switch) {
			setprop("sim/model/danube/systems/warp1-request", 1);
		} else {
			popupTip2("Unable to comply. Main power is off.");
		}
	}
	danube.reloadDialog1();
}

var toggle_warp2 = func {
	if (warp2_request) {
		setprop("sim/model/danube/systems/warp2-request", 0);
	} else {
		if (power_switch) {
			if (warp1_request) {
				setprop("sim/model/danube/systems/warp2-request", 1);
			} else {
				popupTip2("Unable to comply. warp drive is off.");
			}
		} else {
			popupTip2("Unable to comply. Main power is off.");
		}
	}
	danube.reloadDialog1();
}

var toggle_lighting = func(tl_button_num) {
	if (tl_button_num == 5) {
		set_landing_lights(-1);
	} elsif (tl_button_num == 6) {
		set_nav_lights(-1);
	} elsif (tl_button_num == 7) {
		if (beacon_switch.getValue()) {
			beacon_switch.setBoolValue(0);
		} else {
			beacon_switch.setBoolValue(1);
		}
	} elsif (tl_button_num == 8) {
		if (strobe_switch.getValue()) {
			strobe_switch.setBoolValue(0);
		} else {
			strobe_switch.setBoolValue(1);
		}
	} elsif (tl_button_num == 9) {
		if (int_switch) {
			int_switch = 0;
		} else {
			int_switch = 1;
		}
		setprop("sim/model/danube/lighting/interior-switch", int_switch);
		interior_lighting_update();
	}
	danube.reloadDialog1();
}

var delayed_panel_update = func {
	if (!power_switch) {
		setprop("sim/model/danube/systems/impulse-request", 0);
		setprop("sim/model/danube/systems/warp1-request", 0);
		setprop("sim/model/danube/systems/warp2-request", 0);
		popupTip2("Unable to comply. Main power is off.");
	}
}

setlistener("sim/model/danube/crew/cockpit-position", func(n) { cockpitView = n.getValue() });

var set_cockpit = func(cockpitPosition) {
	# axis are different for current-view
	#  x = right/left
	#  y = up/down
	#  z = aft/fore
	if (cockpitPosition > (size(cockpit_locations) - 1)) {
		cockpitPosition = 0;
	}
	if (cockpitPosition < 0) { cockpitPosition = size(cockpit_locations) - 1; }
	setprop("sim/model/danube/crew/cockpit-position", cockpitPosition);
	if (!getprop("sim/walker/outside")) {
		setprop("sim/model/danube/crew/walker/x-offset-m", cockpit_locations[cockpitPosition].x);
		setprop("sim/model/danube/crew/walker/y-offset-m", cockpit_locations[cockpitPosition].y);
	}
	if (getprop("sim/current-view/view-number") == 0) {
		var damage_offset = 0;
		if (cockpitPosition == 0) {  # right side cockpit
			if (damage_count == 1) {
				damage_offset = 0.23;
			} elsif (damage_count == 2) {
				damage_offset = 0.34;
			} elsif (damage_count >= 3) {
				damage_offset = 0.41;
			}
		} else {    # left side cockpit
			if (damage_count == 1) {
				damage_offset = 0.13;
			} elsif (damage_count == 2) {
				damage_offset = 0.24;
			} elsif (damage_count >= 3) {
				damage_offset = 0.31;
			}
		}
		setprop("sim/current-view/z-offset-m", cockpit_locations[cockpitPosition].x);
		setprop("sim/current-view/x-offset-m", cockpit_locations[cockpitPosition].y);
		setprop("sim/current-view/y-offset-m", cockpit_locations[cockpitPosition].z + damage_offset);
		setprop("sim/current-view/goal-heading-offset-deg", cockpit_locations[cockpitPosition].h);
		setprop("sim/current-view/heading-offset-deg", cockpit_locations[cockpitPosition].h);
		setprop("sim/current-view/goal-pitch-offset-deg", cockpit_locations[cockpitPosition].p);
		setprop("sim/current-view/pitch-offset-deg", cockpit_locations[cockpitPosition].p);
		setprop("sim/current-view/field-of-view", cockpit_locations[cockpitPosition].fov);
	}
}

var cycle_cockpit = func(cc_i) {
	if (cc_i == 10) {
		cockpitView = 0;
	} else {
		cockpitView += cc_i;
	}
	set_cockpit(cockpitView);
	if (cc_i == 10) {
		hViewNode.setValue(0.0);
		setprop("sim/current-view/goal-pitch-offset-deg", 0.0);
		setprop("sim/current-view/goal-roll-offset-deg", 0.0);
	}
	if (cockpitView == 5 and getprop("sim/current-view/view-number") == 0) {
		setprop("sim/current-view/goal-pitch-offset-deg", -7.5);
	}
}

var check_auto_doors = func(x_position,y_position) {
	if (door_auto_open[2] == 1) {
		if (x_position >= -10.28 and x_position < -10.03) {
			if (power_switch and door2_opened == 1) {
				select_door(2, 0);
				doors[active_door].close();
				door2_opened = 0;
			}
		} elsif (x_position >= -10.18 and x_position < -8.65 and power_switch) {
			if (y_position > -0.995 and y_position < 1.019) {
				if (door2_opened == 0) {
					select_door(2, 0);
					doors[2].open();
					door2_opened = 1;
				}
			} else {
				if (door2_opened == 1) {
					select_door(2, 0);
					doors[2].close();
					door2_opened = 0;
				}
			}
		} elsif (x_position >= -8.8 and x_position < -8.55) {
			if (power_switch and door2_opened == 1) {
				select_door(2, 0);
				doors[2].close();
				door2_opened = 0;
			}
		}
	}
	if (door_auto_open[3] == 1) {
		if (x_position >= -0.78 and x_position < -0.53) {
			if (power_switch and door3_opened == 1) {
				select_door(3, 0);
				doors[3].close();
				door3_opened = 0;
			}
		} elsif (x_position >= -0.68 and x_position < 0.85) {
			if (y_position > -0.995 and y_position < 1.019) {
				if (door3_opened == 0) {
					select_door(3, 0);
					doors[3].open();
					door3_opened = 1;
				}
			} else {
				if (door3_opened == 1) {
					select_door(3, 0);
					doors[3].close();
					door3_opened = 0;
				}
			}
		} elsif (x_position >= 0.7 and x_position < 0.95) {
			if (power_switch and door3_opened == 1) {
				select_door(3, 0);
				doors[3].close();
				door3_opened = 0;
			}
		}
	}
}

var walk_about_cabin = func(wa_distance, walk_offset) {
	# x,y,z axis are as expected here. Check boundaries/walls.
	#  x = aft/fore
	#  y = right/left
	#  z = up/down
	var w_out = 0;
	var cpos = getprop("sim/model/danube/crew/cockpit-position");
	if (cpos != 0) {
		var view_head = hViewNode.getValue();
		setprop("sim/model/danube/crew/walker/head-offset-deg", view_head);
		var heading = walk_offset + view_head;
		while (heading >= 360.0) {
			heading -= 360.0;
		}
		while (heading < 0.0) {
			heading += 360.0;
		}
		var wa_heading_rad = heading * 0.01745329252;
		var new_x_position = getprop("sim/model/danube/crew/walker/x-offset-m") - (math.cos(wa_heading_rad) * wa_distance);
		var new_y_position = getprop("sim/model/danube/crew/walker/y-offset-m") - (math.sin(wa_heading_rad) * wa_distance);
		var door0_barrier = (door0_position < 0.62 ? -2.04 : -2.77);
		var door1_barrier = (door1_position < 0.62 ? 2.04 : 2.77);
		var c_view = getprop("sim/current-view/view-number");
		if (new_x_position < -12.4) {
			if ((c_view == 0 and getprop("sim/current-view/y-offset-m") >= 0.68) or c_view >0) {
				new_x_position = -12.4;
			}
		}
		# check outside walls
		if (new_x_position <= -14.05) {
			new_x_position = -14.05;
			if (new_y_position < -1.0) {
				new_y_position = -1.0;
			} elsif (new_y_position > 1.0) {
				new_y_position = 1.0;
			}
		} elsif (new_x_position > -14.05 and new_x_position < -13.12) {
			if (new_y_position < -1.0) {
				new_y_position = -1.0;
			} elsif (new_y_position > 1.0) {
				new_y_position = 1.0;
			}
		} elsif (new_x_position > -13.12 and new_x_position < -12.86) {
			var y_angle = (new_x_position + 13.12) / 0.26 * 0.68;
			if (new_y_position < (-1.0 - y_angle)) {
				new_y_position = -1.0 - y_angle;
			} elsif (new_y_position > (1.0 + y_angle)) {
				new_y_position = 1.0 + y_angle;
			}
		} elsif (new_x_position >= -12.86 and new_x_position <= -10.92) {
			if (new_y_position < -1.68) {
				new_y_position = -1.68;
			} elsif (new_y_position > 1.68) {
				new_y_position = 1.68;
			}
		} elsif (new_x_position > -10.92 and new_x_position <= -10.62) {
			if (new_y_position < door0_barrier) {
				new_x_position = -10.62;
				new_y_position = door0_barrier;
			} elsif (new_y_position < -1.98) {
				new_x_position = -10.62;
			} elsif (new_y_position < -1.68) {
				new_y_position = -1.68;
			} elsif (new_y_position > door1_barrier) {
				new_x_position = -10.62;
				new_y_position = door1_barrier;
			} elsif (new_y_position > 1.98) {
				new_x_position = -10.62;
			} elsif (new_y_position > 1.68) {
				new_y_position = 1.68;
			}
		} elsif (new_x_position > -10.62 and new_x_position < -10.08) {
			# between front hatches
			if (new_x_position < -10.62 and 
				(new_y_position < door0_barrier or new_y_position > door1_barrier)) {
					new_x_position = -10.62;
			} elsif (new_x_position > -10.08 and 
				(new_y_position < door0_barrier or new_y_position > door1_barrier)) {
					new_x_position = -10.08;
			}
			if (new_y_position < door0_barrier) {
				if (door0_position > 0.62) {
					w_out = 1;
				}
				new_y_position = door0_barrier;
			} elsif (new_y_position > door1_barrier) {
				if (door1_position > 0.62) {
					w_out = 2;
				}
				new_y_position = door1_barrier;
			}
		} elsif (new_x_position >= -10.08 and new_x_position <= -9.65) {
			if (new_y_position < door0_barrier) {
				new_x_position = -10.08;
				new_y_position = door0_barrier;
			} elsif (new_y_position < -2.1) {
				new_x_position = -10.08;
			} elsif (new_y_position < -1.75) {
				var y_angle = (new_x_position + 9.25) / 0.43 * 0.35;
				if (new_y_position < (-1.75 + y_angle)) {
					new_y_position = -1.75 + y_angle;
				}
			} elsif (new_y_position > door1_barrier) {
				new_x_position = -10.08;
				new_y_position = door1_barrier;
			} elsif (new_y_position > 2.1) {
				new_x_position = -10.08;
			} elsif (new_y_position > 1.75) {
				var y_angle = (new_x_position + 9.25) / 0.43 * 0.35;
				if (new_y_position > (1.75 - y_angle)) {
					new_y_position = 1.75 - y_angle;
				}
			}
		} elsif (new_x_position > -9.65 and new_x_position < -9.42) {
			if (new_y_position < -0.43) {
				new_x_position = -9.65;
				if (new_y_position < -1.75) {
					new_y_position = -1.75;
				}
			} elsif (new_y_position < -0.23) {
				new_y_position = -0.23;
			} elsif (new_y_position > 0.45) {
				new_x_position = -9.65;
				if (new_y_position > 1.75) {
					new_y_position = 1.75;
				}
			} elsif (new_y_position > 0.25) {
				new_y_position = 0.25;
			}
			if (new_y_position > -0.43 and new_y_position < 0.45) {
				if (getprop("sim/model/danube/doors/door[2]/position-norm") < 0.7) {
					new_x_position = -9.65;
				}
			}
		} elsif (new_x_position >= -9.42 and new_x_position < -9.19) {
			if (new_y_position < -0.43) {
				new_x_position = -9.19;
				if (new_y_position < -1.82) {
					new_y_position = -1.82;
				}
			} elsif (new_y_position < -0.23) {
				new_y_position = -0.23;
			} elsif (new_y_position > 0.45) {
				new_x_position = -9.19;
				if (new_y_position > 1.82) {
					new_y_position = 1.82;
				}
			} elsif (new_y_position > 0.25) {
				new_y_position = 0.25;
			}
			if (new_y_position >= -0.43 and new_y_position <= 0.45) {
				if (getprop("sim/model/danube/doors/door[2]/position-norm") < 0.7) {
					new_x_position = -9.19;
				}
			}
		} elsif (new_x_position >= -9.19 and new_x_position <= -8.06) {
			if (new_y_position < -2.0) {
				new_x_position = -8.06;
				if (new_y_position < -2.33) {
					new_y_position = -2.33;
				}
			} elsif (new_y_position < -1.82) {
				new_y_position = -1.82;
			} elsif (new_y_position > 2.0) {
				new_x_position = -8.06;
				if (new_y_position > 2.33) {
					new_y_position = 2.33;
				}
			} elsif (new_y_position > 1.82) {
				new_y_position = 1.82;
			}
		} elsif (new_x_position > -8.06 and new_x_position <= -6.88) {
			if (new_y_position < -2.33) {
				new_y_position = -2.33;
			} elsif (new_y_position > 2.33) {
				new_y_position = 2.33;
			}
		} elsif (new_x_position > -6.88 and new_x_position <= -6.31) {
			if (new_y_position < -1.12) {
				if (new_y_position < -2.33) {
					new_y_position = -2.33;
				}
				var y_angle = (new_x_position + 6.31) / 0.57 * 1.21;
				if (new_y_position < (-1.12 + y_angle)) {
					new_y_position = -1.12 + y_angle;
				}
			} elsif (new_y_position > 1.12) {
				if (new_y_position > 2.33) {
					new_y_position = 2.33;
				}
				var y_angle = (new_x_position + 6.31) / 0.57 * 1.21;
				if (new_y_position > (1.12 - y_angle)) {
					new_y_position = 1.12 - y_angle;
				}
			}
		} elsif (new_x_position > -6.31 and new_x_position < -6.05) {
			if (new_y_position < -0.43) {
				new_x_position = -6.31;
				if (new_y_position < -1.12) {
					new_y_position = -1.12;
				}
			} elsif (new_y_position < -0.23) {
				new_y_position = -0.23;
			} elsif (new_y_position > 0.45) {
				new_x_position = -6.31;
				if (new_y_position > 1.11) {
					new_y_position = 1.11;
				}
			}
		# door would go here
		} elsif (new_x_position >= -6.05 and new_x_position <= -0.15) {
			if (new_y_position < -0.23) {
				new_y_position = -0.23;
			} elsif (new_y_position > 0.25) {
				new_y_position = 0.25;
			}
		} elsif (new_x_position >= -0.15 and new_x_position <= 0.08) {
			if (new_y_position < -0.23) {
				new_y_position = -0.23;
			} elsif (new_y_position > 0.25) {
				new_y_position = 0.25;
			}
			if (new_y_position >= -0.43 and new_y_position <= 0.45) {
				if (getprop("sim/model/danube/doors/door[3]/position-norm") < 0.7) {
					new_x_position = -0.15;
				}
			}
		} elsif (new_x_position >= 0.08 and new_x_position < 0.31) {
			if (new_y_position < -0.43) {
				new_x_position = 0.31;
				if (new_y_position < -1.52) {
					new_y_position = -1.52;
				}
			} elsif (new_y_position < -0.23) {
				new_y_position = -0.23;
			} elsif (new_y_position > 0.45) {
				new_x_position = 0.31;
				if (new_y_position > 1.53) {
					new_y_position = 1.53;
				}
			} elsif (new_y_position > 0.25) {
				new_y_position = 0.25;
			}
			if (new_y_position >= -0.43 and new_y_position <= 0.45) {
				if (getprop("sim/model/danube/doors/door[3]/position-norm") < 0.7) {
					new_x_position = 0.31;
				}
			}
		} elsif (new_x_position >= 0.31 and new_x_position <= 2.34) {
			if (new_y_position < -1.52) {
				new_y_position = -1.52;
			} elsif (new_y_position > 1.53) {
				new_y_position = 1.53;
			}
		} elsif (new_x_position >= 2.34 and new_x_position < 2.69) {
			if (new_y_position < -1.73) {
				new_x_position = 2.69;
				if (new_y_position < -2.54) {
					new_y_position = -2.54;
				}
			} elsif (new_y_position < -1.52) {
				new_y_position = -1.52;
			} elsif (new_y_position > 1.73) {
				new_x_position = 2.69;
				if (new_y_position > 2.54) {
					new_y_position = 2.54;
				}
			} elsif (new_y_position > 1.53) {
				new_y_position = 1.53;
			}
		} elsif (new_x_position >= 2.69 and new_x_position <= 7.55) {
			if (new_y_position < -2.54) {
				new_y_position = -2.54;
			} elsif (new_y_position > 2.54) {
				new_y_position = 2.54;
			}
		} elsif (new_x_position > 7.55) {
			new_x_position = 7.55;
			if (new_y_position < -2.54) {
				new_y_position = -2.54;
			} elsif (new_y_position > 2.54) {
				new_y_position = 2.54;
			}
		}
		# inside walls
		if (new_x_position >= -11.90 and new_x_position < -10.65) {
			if (new_y_position > -1.14 and new_y_position < 1.14) {
				if (new_y_position > -1.14 and new_y_position < -0.79) {
					new_y_position = -1.14;
				} elsif (new_y_position >= -0.79 and new_y_position < -0.44) {
					new_y_position = -0.44;
				} elsif (new_y_position > 0.44 and new_y_position < 0.79) {
					new_y_position = 0.44;
				} elsif (new_y_position >= 0.79 and new_y_position < 1.14) {
					new_y_position = 1.14;
				}
			}
		} elsif (new_x_position >= -8.50 and new_x_position < -8.07 and new_y_position > -1.13 and new_y_position < 1.17) {
			if (new_y_position >= -0.61 and new_y_position <= 0.65) {
				new_x_position = -8.50;
			} else {
				var y_angle = (new_x_position + 8.50) / 0.43 * 0.52;
				if (new_y_position < 0 and new_y_position > (-0.61 - y_angle)) {
					new_y_position = -0.61 - y_angle;
				} elsif (new_y_position > 0 and new_y_position < (0.65 + y_angle)) {
					new_y_position = 0.65 + y_angle;
				}
			}
		} elsif (new_x_position >= -8.07 and new_x_position <= -7.35 and new_y_position > -1.13 and new_y_position < 1.17) {
			if (new_y_position < 0.0) {
				new_y_position = -1.13;
			} else {
				new_y_position = 1.17;
			}
		} elsif (new_x_position > -7.35 and new_x_position <= -7.00 and new_y_position > -1.13 and new_y_position < 1.17) {
			if (new_y_position >= -0.61 and new_y_position <= 0.65) {
				new_x_position = -7.00;
			} else {
				var y_angle = (new_x_position + 7.00) / 0.35 * 0.52;
				if (new_y_position < 0 and new_y_position > (-0.61 + y_angle)) {
					new_y_position = -0.61 + y_angle;
				} elsif (new_y_position > 0 and new_y_position < (0.65 - y_angle)) {
					new_y_position = 0.65 - y_angle;
				}
			}
		}
		# check doors for opening and closing
		check_auto_doors(new_x_position,new_y_position);
		if (w_out) {
			walk.get_out(w_out);
			if (w_out == 1) {
				setprop("sim/model/danube/crew/walker/y-offset-m", -1.87);
			} elsif (w_out ==2) {
				setprop("sim/model/danube/crew/walker/y-offset-m", 1.87);
			}
		} else {
			if (c_view == 0) {
				xViewNode.setValue(new_x_position);
				yViewNode.setValue(new_y_position);
			}
			setprop("sim/model/danube/crew/walker/x-offset-m", new_x_position);
			setprop("sim/model/danube/crew/walker/y-offset-m", new_y_position);
			if (cockpit_locations[cockpitView].can_walk) {
				cockpit_locations[cockpitView].x = new_x_position;
				cockpit_locations[cockpitView].y = new_y_position;
				cockpit_locations[cockpitView].h = view_head;
				cockpit_locations[cockpitView].p = getprop("sim/current-view/pitch-offset-deg");
			}
		}
	}
}

# dialog functions --------------------------------------------------

var set_nav_lights = func(snl_i) {
	var snl_new = nav_light_switch.getValue();
	if (snl_i == -1) {
		snl_new += 1;
		if (snl_new > 2) {
			snl_new = 0;
		}
	} else {
		snl_new = snl_i;
	}
	nav_light_switch.setValue(snl_new);
	active_nav_button = [ 3, 3, 3];
	if (snl_new == 0) {
		active_nav_button[0]=1;
	} elsif (snl_new == 1) {
		active_nav_button[1]=1;
	} else {
		active_nav_button[2]=1;
	}
	nav_lighting_update();
	danube.reloadDialog1();
}

var update_insignia = func {
	var new_li = getprop("sim/model/danube/insignia/number");
	var livery_nt = string.lc(getprop("sim/model/livery/name") ~ "     ");
	if (substr(livery_nt, 0, 5) == "black") {	# if Livery name starts with black then invert the insignia texture color
		var new_bw = "w";
	} else {
		var new_bw = "";
	}
	var new_texture = "NCC" ~ new_li ~ new_bw ~ ".png";
	setprop("sim/model/danube/insignia/texture", new_texture);
}

setlistener("sim/model/danube/insignia/number", func {
	update_insignia();
}, 1, 1);

setlistener("sim/model/livery/name", func {
	update_insignia();
}, 1, 1);

var set_landing_lights = func(sll_i) {
	var sll_new = landing_light_switch.getValue();
	if (sll_i == -1) {  # -1 = increment
		sll_new += 1;
		if (sll_new > 2) {
			sll_new = 0;
		}
	} else {
		sll_new = sll_i;
	}
	landing_light_switch.setValue(sll_new);
	active_landing_button = [ 3, 3, 3];
	if (sll_new == 0) {
		active_landing_button[0]=1;
	} elsif (sll_new == 1) {
		active_landing_button[1]=1;
	} else {
		active_landing_button[2]=1;
	}
	nav_lighting_update();
	danube.reloadDialog1();
}

var toggle_venting_both = func {
	if (!nacelle_R_venting) {
		if (!nacelleL_detached) {
			setprop("sim/model/danube/systems/nacelle-L-venting", 1);
		}
		if (!nacelleR_detached) {
			setprop("sim/model/danube/systems/nacelle-R-venting", 1);
		}
		if (nacelleL_detached and nacelleR_detached) {
			popupTip2("Unable to comply. Too much damage.");
		} else {
			popupTip2("Plasma venting ON");
		}
	} else {
		setprop("sim/model/danube/systems/nacelle-L-venting", 0);
		setprop("sim/model/danube/systems/nacelle-R-venting", 0);
	}
}

var reloadDialog1 = func {
	name = "danube-config";
	interior_lighting_update();
	if (config_dialog != nil) {
		fgcommand("dialog-close", props.Node.new({ "dialog-name" : name }));
		config_dialog = nil;
		showDialog1();
		return;
	}
}

var showDialog = func {
	var c_view = getprop("sim/current-view/view-number");
	var outside = getprop("sim/walker/outside");
	if (outside and ((c_view == view.indexof("Walk View")) or (c_view == view.indexof("Walker Orbit View")))) {
		walker.sequence.showDialog();
	} else {
		danube.showDialog1();
	}
}

var showDialog1 = func {
	name = "danube-config";
	if (config_dialog != nil) {
		fgcommand("dialog-close", props.Node.new({ "dialog-name" : name }));
		config_dialog = nil;
		return;
	}

	config_dialog = gui.Widget.new();
	config_dialog.set("layout", "vbox");
	config_dialog.set("name", name);
	config_dialog.set("x", -40);
	config_dialog.set("y", -40);

 # "window" titlebar
	titlebar = config_dialog.addChild("group");
	titlebar.set("layout", "hbox");
	titlebar.addChild("empty").set("stretch", 1);
	titlebar.addChild("text").set("label", "Danube class Runabout systems and configuration");
	titlebar.addChild("empty").set("stretch", 1);

	config_dialog.addChild("hrule").addChild("dummy");

	w = titlebar.addChild("button");
	w.set("pref-width", 16);
	w.set("pref-height", 16);
	w.set("legend", "");
	w.set("default", 1);
	w.set("keynum", 27);
	w.set("border", 1);
	w.prop().getNode("binding[0]/command", 1).setValue("nasal");
	w.prop().getNode("binding[0]/script", 1).setValue("danube.config_dialog = nil");
	w.prop().getNode("binding[1]/command", 1).setValue("dialog-close");

	var checkbox = func {
		group = config_dialog.addChild("group");
		group.set("layout", "hbox");
		group.addChild("empty").set("pref-width", 4);
		var box = group.addChild("checkbox");
		group.addChild("text").set("label", arg[0]);
		group.addChild("empty").set("stretch", 1);

		box.set("halign", "left");
		box.set("label", "");
		box.set("live", 1);
		return box;
	}

 # master power switch
	var w = checkbox("master power                       [~]");
	w.setColor(0.45, (0.45 + (getprop("sim/model/danube/systems/power-switch") * 0.55)), 0.45);
	w.set("property", "sim/model/danube/systems/power-switch");
	w.prop().getNode("binding[0]/command", 1).setValue("dialog-apply");
	w.prop().getNode("binding[1]/command", 1).setValue("nasal");
	w.prop().getNode("binding[1]/script", 1).setValue("danube.toggle_power(9)");

 # impulse intake manifold glow
	w = checkbox("impulse engines                     [\]");
	w.setColor(0.45, (0.45 + (getprop("sim/model/danube/systems/impulse-request") * 0.55)), 0.45);
	w.set("property", "sim/model/danube/systems/impulse-request");
	w.prop().getNode("binding[0]/command", 1).setValue("dialog-apply");
	w.prop().getNode("binding[1]/command", 1).setValue("nasal");
	w.prop().getNode("binding[1]/script", 1).setValue("danube.delayed_panel_update()");
	w.prop().getNode("binding[2]/command", 1).setValue("nasal");
	w.prop().getNode("binding[2]/script", 1).setValue("danube.reloadDialog1()");

 # warp drive backlight glow
	w = checkbox("warp engine                     [space]");
	w.setColor(0.45, (0.45 + (getprop("sim/model/danube/systems/warp1-request") * 0.55)), 0.45);
	w.set("property", "sim/model/danube/systems/warp1-request");
	w.prop().getNode("binding[0]/command", 1).setValue("dialog-apply");
	w.prop().getNode("binding[1]/command", 1).setValue("nasal");
	w.prop().getNode("binding[1]/script", 1).setValue("danube.delayed_panel_update()");
	w.prop().getNode("binding[2]/command", 1).setValue("nasal");
	w.prop().getNode("binding[2]/script", 1).setValue("danube.reloadDialog1()");

 # extra glow and orbital velocities
	w = checkbox("increase plasma flow to warp drive");
	w.setColor(0.45, (0.45 + (getprop("sim/model/danube/systems/warp2-request") * 0.55)), 0.45);
	w.set("property", "sim/model/danube/systems/warp2-request");
	w.prop().getNode("binding[0]/command", 1).setValue("dialog-apply");
	w.prop().getNode("binding[1]/command", 1).setValue("nasal");
	w.prop().getNode("binding[1]/script", 1).setValue("danube.delayed_panel_update()");
	w.prop().getNode("binding[2]/command", 1).setValue("nasal");
	w.prop().getNode("binding[2]/script", 1).setValue("danube.reloadDialog1()");

	config_dialog.addChild("hrule").addChild("dummy");

 # lights
	var g = config_dialog.addChild("group");
	g.set("layout", "hbox");
	g.addChild("empty").set("pref-width", 4);
	w = g.addChild("text");
	w.set("halign", "left");
	w.set("label", "nav lights:");
	g.addChild("empty").set("stretch", 1);

	g = config_dialog.addChild("group");
	g.set("layout", "hbox");
	g.addChild("empty").set("pref-width", 4);

	var box = g.addChild("button");
	g.addChild("empty").set("stretch", 1);
	box.set("halign", "left");
	box.set("label", "");
	box.set("pref-width", 100);
	box.set("pref-height", 18);
	box.set("legend", "Stay On");
	box.set("border", active_nav_button[2]);
	box.setColor(0.45, (0.975 - (active_nav_button[2] * 0.175)), 0.45);
	box.prop().getNode("binding[0]/command", 1).setValue("nasal");
	box.prop().getNode("binding[0]/script", 1).setValue("danube.set_nav_lights(2)");
	box.prop().getNode("binding[1]/command", 1).setValue("nasal");
	box.prop().getNode("binding[1]/script", 1).setValue("danube.reloadDialog1()");

	box = g.addChild("button");
	g.addChild("empty").set("pref-width", 4);
	box.set("halign", "left");
	box.set("label", "");
	box.set("pref-width", 130);
	box.set("pref-height", 18);
	box.set("legend", "Dusk to Dawn");
	box.set("border", active_nav_button[1]);
	box.setColor(0.45, (0.975 - (active_nav_button[1] * 0.175)), 0.45);
	box.prop().getNode("binding[0]/command", 1).setValue("nasal");
	box.prop().getNode("binding[0]/script", 1).setValue("danube.set_nav_lights(1)");
	box.prop().getNode("binding[1]/command", 1).setValue("nasal");
	box.prop().getNode("binding[1]/script", 1).setValue("danube.reloadDialog1()");

	box = g.addChild("button");
	g.addChild("empty").set("pref-width", 4);
	box.set("halign", "left");
	box.set("label", "");
	box.set("pref-width", 50);
	box.set("pref-height", 18);
	box.set("legend", "Off");
	box.set("border", active_nav_button[0]);
	box.setColor((0.975 - (active_nav_button[0] * 0.175)), 0.45, 0.45);
	box.prop().getNode("binding[0]/command", 1).setValue("nasal");
	box.prop().getNode("binding[0]/script", 1).setValue("danube.set_nav_lights(0)");
	box.prop().getNode("binding[1]/command", 1).setValue("nasal");
	box.prop().getNode("binding[1]/script", 1).setValue("danube.reloadDialog1()");

	w = checkbox("beacons");
	w.setColor(0.45, (0.45 + (getprop("controls/lighting/beacon") * 0.55)), 0.45);
	w.set("property", "controls/lighting/beacon");
	w.prop().getNode("binding[0]/command", 1).setValue("dialog-apply");
	w.prop().getNode("binding[1]/command", 1).setValue("nasal");
	w.prop().getNode("binding[1]/script", 1).setValue("danube.reloadDialog1()");

	w = checkbox("strobes");
	w.setColor(0.45, (0.45 + (getprop("controls/lighting/strobe") * 0.55)), 0.45);
	w.set("property", "controls/lighting/strobe");
	w.prop().getNode("binding[0]/command", 1).setValue("dialog-apply");
	w.prop().getNode("binding[1]/command", 1).setValue("nasal");
	w.prop().getNode("binding[1]/script", 1).setValue("danube.reloadDialog1()");

 # landing lights
	g = config_dialog.addChild("group");
	g.set("layout", "hbox");
	g.addChild("empty").set("pref-width", 4);
	w = g.addChild("text");
	w.set("halign", "left");
	w.set("label", "landing lights:");
	g.addChild("empty").set("stretch", 1);

	g = config_dialog.addChild("group");
	g.set("layout", "hbox");
	g.addChild("empty").set("pref-width", 4);

	box = g.addChild("button");
	g.addChild("empty").set("stretch", 1);
	box.set("halign", "left");
	box.set("label", "");
	box.set("pref-width", 100);
	box.set("pref-height", 18);
	box.set("legend", "Stay On");
	box.set("border", active_landing_button[2]);
	box.setColor(0.45, (0.975 - (active_landing_button[2] * 0.175)), 0.45);
	box.prop().getNode("binding[0]/command", 1).setValue("nasal");
	box.prop().getNode("binding[0]/script", 1).setValue("danube.set_landing_lights(2)");
	box.prop().getNode("binding[1]/command", 1).setValue("nasal");
	box.prop().getNode("binding[1]/script", 1).setValue("danube.reloadDialog1()");

	box = g.addChild("button");
	g.addChild("empty").set("pref-width", 4);
	box.set("halign", "left");
	box.set("label", "");
	box.set("pref-width", 130);
	box.set("pref-height", 18);
	box.set("legend", "Dusk to Dawn");
	box.set("border", active_landing_button[1]);
	box.setColor(0.45, (0.975 - (active_landing_button[1] * 0.175)), 0.45);
	box.prop().getNode("binding[0]/command", 1).setValue("nasal");
	box.prop().getNode("binding[0]/script", 1).setValue("danube.set_landing_lights(1)");
	box.prop().getNode("binding[1]/command", 1).setValue("nasal");
	box.prop().getNode("binding[1]/script", 1).setValue("danube.reloadDialog1()");

	box = g.addChild("button");
	g.addChild("empty").set("pref-width", 4);
	box.set("halign", "left");
	box.set("label", "");
	box.set("pref-width", 50);
	box.set("pref-height", 18);
	box.set("legend", "Off");
	box.set("border", active_landing_button[0]);
	box.setColor((0.975 - (active_landing_button[0] * 0.175)), 0.45, 0.45);
	box.prop().getNode("binding[0]/command", 1).setValue("nasal");
	box.prop().getNode("binding[0]/script", 1).setValue("danube.set_landing_lights(0)");
	box.prop().getNode("binding[1]/command", 1).setValue("nasal");
	box.prop().getNode("binding[1]/script", 1).setValue("danube.reloadDialog1()");

 # interior
	w = checkbox("interior lights");
	w.setColor(0.45, (0.45 + (getprop("sim/model/danube/lighting/interior-switch") * 0.55)), 0.45);
	w.set("property", "sim/model/danube/lighting/interior-switch");
	w.prop().getNode("binding[0]/command", 1).setValue("dialog-apply");
	w.prop().getNode("binding[1]/command", 1).setValue("nasal");
	w.prop().getNode("binding[1]/script", 1).setValue("danube.nav_lighting_update()");
	w.prop().getNode("binding[2]/command", 1).setValue("nasal");
	w.prop().getNode("binding[2]/script", 1).setValue("danube.reloadDialog1()");

 # red-alert and damage
	w = checkbox("Condition Red alert");
	w.setColor((0.45 + (getprop("controls/lighting/alert") * 0.55)), 0.45, 0.45);
	w.set("property", "controls/lighting/alert");
	w.prop().getNode("binding[0]/command", 1).setValue("dialog-apply");
	w.prop().getNode("binding[1]/command", 1).setValue("nasal");
	w.prop().getNode("binding[1]/script", 1).setValue("danube.reloadDialog1()");

 # interior panel
	w = checkbox("LCARS panel");
	w.setColor(0.45, (0.45 + (getprop("sim/model/danube/lighting/LCARS-panel") * 0.55)), 0.45);
	w.set("property", "sim/model/danube/lighting/LCARS-panel");
	w.prop().getNode("binding[0]/command", 1).setValue("dialog-apply");
	w.prop().getNode("binding[1]/command", 1).setValue("nasal");
	w.prop().getNode("binding[1]/script", 1).setValue("danube.reloadDialog1()");

	config_dialog.addChild("hrule").addChild("dummy");

 # insignia
	g = config_dialog.addChild("group");
	g.set("layout", "hbox");
	g.addChild("empty").set("pref-width", 4);
	w = g.addChild("text");
	w.set("halign", "left");
	w.set("label", "Registry:");
	g.addChild("empty").set("stretch", 1);

	var registry_current = insignia_node.getValue();
	var registry_description = "";
	var combo = g.addChild("combo");
	combo.set("default-padding", 1);
	combo.set("default-value", "None");
	combo.set("pref-width", 250);
	combo.set("live", 1);
	combo.set("property", "/sim/gui/dialogs/insignia");
	combo.prop().getNode("value[0]", 1).setValue("None");
	for (var i = 0 ; i < size(registry_list) ; i += 1) {
		var reg_desc = "NCC-" ~ registry_list[i].number ~ " " ~ registry_list[i].name;
		combo.set("value[" ~ (i+1) ~ "]", reg_desc);
		if (registry_current == registry_list[i].number) {
			registry_description = reg_desc;
		}
	}
	gui_insignia_node.setValue(registry_description);
	combo.prop().getNode("binding[0]/command", 1).setValue("dialog-apply");
	combo.prop().getNode("binding[1]/command", 1).setValue("nasal");
	combo.prop().getNode("binding[1]/script", 1).setValue("danube.combobox_apply()");
	g.addChild("empty").set("pref-width", 4);

	config_dialog.addChild("hrule").addChild("dummy");

	w = checkbox("Transparent windows");
	w.set("property", "sim/model/cockpit-visible");
	w.prop().getNode("binding[0]/command", 1).setValue("dialog-apply");
	w.prop().getNode("binding[1]/command", 1).setValue("nasal");
	w.prop().getNode("binding[1]/script", 1).setValue("danube.nav_lighting_update()");
	w.prop().getNode("binding[2]/command", 1).setValue("nasal");
	w.prop().getNode("binding[2]/script", 1).setValue("danube.reloadDialog1()");

 # simple and fast shadow - alternative to Rendered AC shadow
	w = checkbox("Simple 2D shadow");
	w.set("property", "sim/model/danube/shadow");
	w.prop().getNode("binding[0]/command", 1).setValue("dialog-apply");

 # This runabout is configured with living space as module2
 # only module1 can detach.
	w = checkbox("Detach Module1");
	w.set("property", "sim/model/danube/components/module1-detached");
	w.prop().getNode("binding[0]/command", 1).setValue("dialog-apply");

	config_dialog.addChild("hrule").addChild("dummy");

 # walk around cabin
	g = config_dialog.addChild("group");
	g.set("layout", "hbox");
	g.addChild("empty").set("pref-width", 4);
	w = g.addChild("text");
	w.set("halign", "left");
	w.set("label", "Move around cockpit:");
	g.addChild("empty").set("stretch", 1);

	g = config_dialog.addChild("group");
	g.set("layout", "hbox");
	g.addChild("empty").set("pref-width", 40);
	w = g.addChild("text");
	w.set("halign", "left");
	w.set("label", "Jump to:");
	g.addChild("empty").set("stretch", 1);

	box = g.addChild("button");
	g.addChild("empty").set("pref-width", 4);
	box.set("halign", "left");
	box.set("label", "");
	box.set("pref-width", 130);
	box.set("pref-height", 19);
	box.set("legend", "Pilot's chair");
	box.set("border", 3);
	box.prop().getNode("binding[0]/command", 1).setValue("nasal");
	box.prop().getNode("binding[0]/script", 1).setValue("danube.set_cockpit(0)");

	g = config_dialog.addChild("group");
	g.set("layout", "hbox");
	g.addChild("empty").set("stretch", 1);

	box = g.addChild("button");
	box.set("halign", "left");
	box.set("label", "");
	box.set("pref-width", 130);
	box.set("pref-height", 19);
	box.set("legend", "Behind pilot");
	box.set("border", 3);
	box.prop().getNode("binding[0]/command", 1).setValue("nasal");
	box.prop().getNode("binding[0]/script", 1).setValue("danube.set_cockpit(3)");

	box = g.addChild("button");
	g.addChild("empty").set("pref-width", 4);
	box.set("halign", "left");
	box.set("label", "");
	box.set("pref-width", 130);
	box.set("pref-height", 19);
	box.set("legend", "Between doors");
	box.set("border", 3);
	box.prop().getNode("binding[0]/command", 1).setValue("nasal");
	box.prop().getNode("binding[0]/script", 1).setValue("danube.set_cockpit(1)");

	w = checkbox("Pilot visible as separate person");
	w.set("property", "sim/model/danube/crew/pilot/visible");
	w.prop().getNode("binding[0]/command", 1).setValue("dialog-apply");

	g = config_dialog.addChild("group");
	g.set("layout", "hbox");
	g.addChild("empty").set("pref-width", 4);
	var box = g.addChild("checkbox");
	box.set("halign", "left");
	box.set("label", "");
	box.set("live", 1);
	box.set("property", "sim/model/danube/crew/walker/visible");
	box.prop().getNode("binding[0]/command", 1).setValue("dialog-apply");
	g.addChild("text").set("label", "Walker visible");
	g.addChild("empty").set("stretch", 1);
	box = g.addChild("button");
	g.addChild("empty").set("pref-width", 4);
	box.set("halign", "left");
	box.set("label", "");
	box.set("pref-width", 130);
	box.set("pref-height", 19);
	box.set("legend", "Animations");
	box.set("border", 3);
	box.prop().getNode("binding[0]/command", 1).setValue("nasal");
	box.prop().getNode("binding[0]/script", 1).setValue("walker.sequence.showDialog()");
	box.prop().getNode("binding[1]/command", 1).setValue("nasal");
	box.prop().getNode("binding[1]/script", 1).setValue("danube.config_dialog = nil");
	box.prop().getNode("binding[2]/command", 1).setValue("dialog-close");

	config_dialog.addChild("hrule").addChild("dummy");

	w = checkbox("Output position of walker/skydiver");
	w.set("property", "logging/walker-position");
	w.prop().getNode("binding[0]/command", 1).setValue("dialog-apply");

	w = checkbox("Output debug of walker");
	w.set("property", "logging/walker-debug");
	w.prop().getNode("binding[0]/command", 1).setValue("dialog-apply");
 # finale
	config_dialog.addChild("empty").set("pref-height", "3");
	fgcommand("dialog-new", config_dialog.prop());
	gui.showDialog(name);
}

var gui_livery_node = props.globals.getNode("/sim/gui/dialogs/livery", 1);
var livery_hull_list = [ "hull-1", "hull-2", "hull-3", "texture-4", "texture-5", "texture-6", "texture-7", "texture-8", "texture-9", "hull-cockpit", "stripe"];
if (gui_livery_node.getNode("list") == nil) {
	gui_livery_node.getNode("list", 1).setValue("");
}
for (var i = 0; i < size(livery_hull_list); i += 1) {
	gui_livery_node.getNode("list["~i~"]", 1).setValue(livery_hull_list[i]);
}
gui_livery_node = gui_livery_node.getNode("list", 1);

var listbox_apply = func {
	material.showDialog("sim/model/livery/material/" ~ gui_livery_node.getValue() ~ "/", nil, getprop("/sim/startup/xsize") - 200, 20);
}

var showLiveryDialog1 = func {
	name = "danube-livery-select";
	if (livery_dialog != nil) {
		fgcommand("dialog-close", props.Node.new({ "dialog-name" : name }));
		livery_dialog = nil;
		return;
	}

	livery_dialog = gui.Widget.new();
	livery_dialog.set("layout", "vbox");
	livery_dialog.set("name", name);
	livery_dialog.set("x", 40);
	livery_dialog.set("y", -40);

 # "window" titlebar
	titlebar = livery_dialog.addChild("group");
	titlebar.set("layout", "hbox");
	titlebar.addChild("empty").set("stretch", 1);
	titlebar.addChild("text").set("label", "Danube class Runabout");
	titlebar.addChild("empty").set("stretch", 1);

	livery_dialog.addChild("hrule").addChild("dummy");

	w = titlebar.addChild("button");
	w.set("pref-width", 16);
	w.set("pref-height", 16);
	w.set("legend", "");
	w.set("default", 1);
	w.set("keynum", 27);
	w.set("border", 1);
	w.prop().getNode("binding[0]/command", 1).setValue("nasal");
	w.prop().getNode("binding[0]/script", 1).setValue("danube.livery_dialog = nil");
	w.prop().getNode("binding[1]/command", 1).setValue("dialog-close");

	g = livery_dialog.addChild("group");
	g.set("layout", "hbox");
	g.addChild("empty").set("pref-width", 4);
	w = g.addChild("text");
	w.set("halign", "left");
	w.set("label", "Edit External Livery Hull materials:");
	g.addChild("empty").set("stretch", 1);

	var a = livery_dialog.addChild("list");
	a.set("name", "livery-hull-list");
	a.set("pref-width", 300);
	a.set("pref-height", 160);
	a.set("slider", 18);
	a.set("property", "/sim/gui/dialogs/livery/list");
	for (var i = 0 ; i < size(livery_hull_list) ; i += 1) {
		a.set("value[" ~ i ~ "]", livery_hull_list[i]);
	}
	a.prop().getNode("binding[0]/command", 1).setValue("dialog-apply");
	a.prop().getNode("binding[0]/object-name", 1).setValue("livery-hull-list");
	a.prop().getNode("binding[1]/command", 1).setValue("nasal");
	a.prop().getNode("binding[1]/script", 1).setValue("danube.listbox_apply()");
	g.addChild("empty").set("pref-width", 4);

	livery_dialog.addChild("empty").set("pref-height", "3");
	fgcommand("dialog-new", livery_dialog.prop());
	gui.showDialog(name);
}

var ignite = func {
	var desc = getprop("sim/description");
	var lat_deg = getprop("position/latitude-deg");
	var lon_deg = getprop("position/longitude-deg");
	var alt_ft = ground_elevation_ft.getValue();
	wildfire.ignite(geo.Coord.new().set_latlon(lat_deg,lon_deg,alt_ft), 1);
}

#==========================================================================
#                 === initial calls at startup ===
setlistener("sim/signals/fdm-initialized", func {
	update_main();  # starts continuous loop
	settimer(interior_lighting_loop, 0.25);
	settimer(interior_lighting_update, 0.5);
	settimer(nav_light_loop, 0.5);
	settimer(reset_landing, 1.0);
	if (getprop("sim/ai-traffic/enabled") or getprop("sim/multiplay/rxport")) {
		setprop("instrumentation/tracking/enabled", 1);
	}
	aircraft.livery.select(getprop("sim/model/livery/name"));
	setprop("sim/atc/enabled", 0);
	setprop("sim/sound/chatter", 0);

	print ("Danube Class Runabout  by Stewart Andreason");
	print ("  based on mesh by Matthew Allen");
	print ("  version 41.6  release date 2014.Feb.04  for FlightGear >= 1.9");
});
