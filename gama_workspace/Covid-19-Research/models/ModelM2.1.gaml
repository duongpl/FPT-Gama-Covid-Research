
model flood

/* Insert your model definition here */
global {

// Starting date of the simulation
//date starting_date <- #now;

// Time step to represent very short term movement (for congestion)
	float step <- 10 #sec;
	int nb_of_people;

	// To initialize perception distance of inhabitant
	float min_perception_distance <- 10.0;
	float max_perception_distance <- 30.0;

	// Represents the capacity of a road indicated as: number of inhabitant per #m of road
	float road_density;

	// Parameters of the strategy
	int time_after_last_stage;
	string the_alert_strategy;
	int nb_stages;

	// Parameters of hazard
	int time_before_hazard;
	float flood_front_speed;
	shape_file shapefile_homes <- shape_file("includes/home/home.shp");
	shape_file shapefile_industry <- shape_file("includes/industry/industry.shp");
	shape_file shapefile_office <- shape_file("includes/office/office.shp");
	shape_file shapefile_park <- shape_file("includes/park/park.shp");
	shape_file shapefile_school <- shape_file("includes/school/school.shp");
	shape_file shapefile_supermarket <- shape_file("includes/supermarket/supermarket.shp");
	shape_file shapefile_roads <- shape_file("includes/clean_roads.shp");
	shape_file shapefile_evacuations <- shape_file("includes/evacuation.shp");
	shape_file shapefile_redriver <- shape_file("includes/RedRiver_scnr1.shp");
	geometry shape <- envelope(envelope(shapefile_roads) + envelope(shapefile_redriver));

	// Graph road
	graph<geometry, geometry> road_network;
	map<road, float> road_weights;

	// Output the number of casualties
	int casualties;

	init {
		create road from: shapefile_roads;
		create home from: shapefile_homes;
		create industry from: shapefile_industry;
		create office from: shapefile_office;
		create park from: shapefile_park;
		create school from: shapefile_school;
		create supermarket from: shapefile_supermarket;
		create hazard from: shapefile_redriver;
		create inhabitant number: nb_of_people {
			int live_in <- rnd(1, 6);
			switch live_in {
				match 1 {
					location <- any_location_in(one_of(home));
				}

				match 2 {
					location <- any_location_in(one_of(industry));
				}

				match 3 {
					location <- any_location_in(one_of(office));
				}

				match 4 {
					location <- any_location_in(one_of(park));
				}

				match 5 {
					location <- any_location_in(one_of(school));
				}

				match 6 {
					location <- any_location_in(one_of(supermarket));
				}

			}

			perception_distance <- rnd(min_perception_distance, max_perception_distance);
		}

//		create crisis_manager;
		road_network <- as_edge_graph(road);
		road_weights <- road as_map (each::each.shape.perimeter);
	}

	date starting_date <- date([2019, 3, 22, 6, 0, 0]);

	reflex show_time {
		write sample(cycle);
		write sample(time);
		write sample(current_date);
		write "===================";
	}

	reflex clock when: (current_date.hour = 7) and (current_date.minute = 0) {
		write "------------";
		write "wake up time";
		write "------------";
	}

	reflex endclock when: (current_date.hour = 17) and (current_date.minute = 0) {
		write "------------";
		write "end working day";
		write "------------";
	}

	reflex crisis when: (current_date.day = 22) and (current_date.hour = 7) {
		write "------------";
		write "Flood! Evacuation";
		write "------------";
	}

	reflex break when: every(#hour) {
		write "-------------";
		write "break time";
		write "----------";
	}
	// Stop the simulation when everyone is either saved :) or dead :(
	reflex stop_simu when: inhabitant all_match (each.saved or each.drowned) {
		do pause;
	}

}



/*
 * Represent the water body. When attribute triggered is turn to true, inhabitant
 * start to see water as a potential danger, and try to escape
 */
species hazard {

// The date of the hazard
	date catastrophe_date;

	// Is it a tsunami ? (or just a little regular wave)
	bool triggered;

	init {
		catastrophe_date <- current_date + time_before_hazard #mn;
	}

	/*
	 * The shape the represent the water expend every cycle to mimic a (big) wave
	 */
	reflex expand when: catastrophe_date < current_date {
		if (not (triggered)) {
			triggered <- true;
		}

//		shape <- shape buffer (flood_front_speed #m / #mn * step) intersection world;
	}

	aspect default {
		draw shape color: #blue;
	}

}

/*
 * Represent the inhabitant of the area. They move at foot. They can pereive the hazard or be alerted
 * and then will try to reach the one randomly choose exit point
 */
species inhabitant skills: [moving] {

// The state of the agent
	bool alerted <- false;
	bool drowned <- false;
	bool saved <- false;

	// How far (#m) they can perceive
	float perception_distance;

	// The exit point they choose to reach
	//	evacuation_point safety_point;
	// How fast inhabitant can run
	float speed <- 10 #km / #h;

	/*
	 * Am I drowning ?
	 */


	/*
	 * Is there any danger around ?
	 */


	/*
	 * When alerted people will try to go to the choosen exit point
	 */

/*
	 * Am I safe ?
	 */
	

}

/*

/*
 * The roads inhabitant will use to evacuate. Roads compute the congestion of road segment
 * accordin to the Underwood function.
 */
species road {

// Number of user on the road section
	int users;
	// The capacity of the road section
	float capacity <- 1 + shape.perimeter / 30;
	//int capacity <- int(shape.perimeter*road_density);
	// The Underwood coefficient of congestion
	float speed_coeff <- 1.0;

	// Update weights on road to compute shortest path and impact inhabitant movement
	reflex update_weights {
		speed_coeff <- max(0.05, exp(-users / capacity));
		road_weights[self] <- shape.perimeter / speed_coeff;
		users <- 0;
	}

	//	// Cut the road when flooded so people cannot use it anymore
	//	reflex flood_road {
	//		if(hazard first_with (each covers self) != nil){
	//			road_network >- self; 
	//			do die;
	//		}
	//	}
	//	
	aspect default {
		draw shape width: 4 #m - (3 * speed_coeff) #m color: rgb(55 + 200 * users / capacity, 0, 0);
	}

}

/*
 * People are located in building at the start of the simulation
 */
species home {

	aspect default {
		draw shape color: #red border: #black;
	}

}

species industry {

	aspect default {
		draw shape color: #gray border: #black;
	}

}

species office {

	aspect default {
		draw shape color: #blue border: #black;
	}

}

species park {

	aspect default {
		draw shape color: #green border: #black;
	}

}

species school {

	aspect default {
		draw shape color: #yellow border: #black;
	}

}

species supermarket {

	aspect default {
		draw shape color: #violet border: #black;
	}

}

experiment "Run" {
	float minimum_cycle_duration <- 0.1;
	parameter "Alert Strategy" var: the_alert_strategy init: "STAGED" among: ["NONE", "STAGED", "SPATIAL", "EVERYONE"] category: "Alert";
	parameter "Number of stages" var: nb_stages init: 6 category: "Alert";
	parameter "Time alert buffer before hazard" var: time_after_last_stage init: 5 unit: #mn category: "Alert";
	parameter "Road density index" var: road_density init: 6.0 min: 0.1 max: 10.0 category: "Congestion";
	parameter "Speed of the flood front" var: flood_front_speed init: 5.0 min: 1.0 max: 30.0 unit: #m / #mn category: "Hazard";
	parameter "Time before hazard" var: time_before_hazard init: 5 min: 0 max: 10 unit: #mn category: "Hazard";
	parameter "Number of people" var: nb_of_people init: 500 min: 100 max: 20000 category: "Initialization";
	output {
		display my_display type: opengl {
			species road;
			species hazard;
			species home;
			species industry;
			species office;
			species park;
			species school;
			species supermarket;
			species inhabitant;
		}

		monitor "Number of casualties" value: casualties;
	}

}
