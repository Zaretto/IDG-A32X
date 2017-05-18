# A320Family FMGC
# Joshua Davidson (it0uchpods) and Jonathan Redpath (legoboyvdlp)

##################
# Init Functions #
##################

setprop("/position/gear-agl-ft", 0);

var FMGCinit = func {
	setprop("/FMGC/status/to-state", 0);
	setprop("/FMGC/status/phase", "0"); # 0 is preflight 1 takeoff 2 climb 3 cruise 4 descent 5 approach 6 go around 7 done
	setprop("/FMGC/internal/cruise-ft", 10000);
	setprop("/FMGC/internal/cruise-fl", 100);
	setprop("/FMGC/internal/tropo", 36090);
	setprop("/FMGC/internal/cost-index", "0");
	setprop("/FMGC/internal/greendot-kts", 0);
	phasecheck.start();
	greendott.start();
}

#############
# TO Status #
#############

setlistener("/gear/gear[1]/wow", func {
	flarecheck();
});

setlistener("/gear/gear[2]/wow", func {
	flarecheck();
});

var flarecheck = func {
	var gear1 = getprop("/gear/gear[1]/wow");
	var gear2 = getprop("/gear/gear[2]/wow");
	var state1 = getprop("/systems/thrust/state1");
	var state2 = getprop("/systems/thrust/state2");
	var flaps = getprop("/controls/flight/flap-pos");
	if (gear1 == 1 and gear2 == 1 and (state1 == "MCT" or state1 == "MAN THR" or state1 == "TOGA") and (state2 == "MCT" or state2 == "MAN THR" or state2 == "TOGA") and flaps < 4) {
		setprop("/FMGC/status/to-state", 1);
	}
	if (getprop("/position/gear-agl-ft") >= 55) {
		setprop("/FMGC/status/to-state", 0);
	}
	if (gear1 == 1 and gear2 == 1 and getprop("/FMGC/status/to-state") == 0 and flaps >= 4) {
		setprop("/controls/flight/elevator-trim", -0.15);
	}
}

################
# Flight Phase #
################

var phasecheck = maketimer(0.2, func { 
	var n1_left = getprop("/engines/engine[0]/n1");
	var n1_right = getprop("/engines/engine[1]/n1");
	var flaps = getprop("/controls/flight/flap-pos");
	var mode = getprop("/modes/pfd/fma/pitch-mode");
	var gs = getprop("/velocities/groundspeed-kt");
	var alt = getprop("/instrumentation/altimeter/indicated-altitude-ft");
	var cruisefl = getprop("/FMGC/internal/cruise-ft");
	var newcruise = getprop("/it-autoflight/internal/alt");
	var phase = getprop("/FMGC/status/phase");
	var state1 = getprop("/systems/thrust/state1");
	var state2 = getprop("/systems/thrust/state2");
	var wowl = getprop("/gear/gear[1]/wow");
	var wowr = getprop("/gear/gear[2]/wow");
	var targetalt = getprop("/it-autoflight/internal/alt");
	var targetvs = getprop("/it-autoflight/input/vs");
	var targetfpa = getprop("/it-autoflight/input/fpa");
	var vertmode = getprop("/modes/pfd/fma/pitch-mode");
	if ((((n1_left >= 85) and (n1_right >= 85)) or (gs > 90 )) and flaps < 4 and (mode == "SRS")) {
		setprop("/FMGC/status/phase", "1");
	}
	if ((alt >= 3000) and (alt <= cruisefl) and (phase == "1") and (phase != "4") and (mode != "SRS")) {
		setprop("/FMGC/status/phase", "2");
	}
	if ((alt >= cruisefl) and (phase == "2") and (mode != "SRS")) {
		setprop("/FMGC/status/phase", "3"); # for now cruise will be level 100 or above until the MCDU is ready
	}
	if ((alt <= cruisefl) and (phase == "3")) { # for now it will have to be when we begin descent.
		setprop("/FMGC/status/phase", "4");
	}
	if (getprop("/FMGC/status/to-state") == 0 and flaps >= 4 and ((phase == "4") or (phase == "2"))) { # add man activation of approach phase in MCDU or DECEL when those things are simulated
		setprop("/FMGC/status/phase", "5");
	}
	if ((phase == "5") and (state1 == "TOGA") and (state2 == "TOGA")) { # this is the only fully correct one to FCOM
		setprop("/FMGC/status/phase", "6");
	}
	# forget transition from APP to climb for now because it would be too complex
	if ((phase == "6") and ((vertmode == "G/A CLB") or (vertmode == "SPD CLB") or (vertmode == "CLB") or ((vertmode == "V/S") and (targetvs > 0)) or ((vertmode == "FPA") and (targetfpa > 0))) and (alt <= targetalt)) {
		setprop("/FMGC/status/phase", "2"); # going to CLIMB mode from GA
	}
	if ((wowl and wowr) and (gs < 20) and (phase == "5")) { # below twenty knots.
		setprop("/FMGC/status/phase", "7");
		settimer(func {
			itaf.ap_init();
			FMGCinit();
			mcdu1.MCDU_reset();
			mcdu2.MCDU_reset();
		}, 30);
	}
});

var greendott = maketimer(0.1, func {
	var gwlb = getprop("fdm/jsbsim/inertia/weight-lbs");
	var factor = 0.45359237;
	var kg = (gwlb * factor);
	var alt = getprop("position/altitude-ft");
	var kg2= (kg / 1000);
	var greendot = ((kg2 * 2) + 85);
	setprop("/FMGC/internal/greendot-kts", greendot);
});
	