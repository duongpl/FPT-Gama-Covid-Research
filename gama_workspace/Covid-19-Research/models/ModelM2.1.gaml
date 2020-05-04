model flood

/* Insert your model definition here */
global {
	int num_of_susceptible <- 500;
	int num_of_infectious <- 100;
	float mask_rate <- 0.8;
	float type_I <- 0.7;
	float infected_rate <- 1.0;
	float infected_rateA <- 0.55;
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
	shape_file shapefile_buildings <- shape_file("../includes/buildings/buildings.shp");
	shape_file shapefile_homes <- shape_file("../includes/home/home.shp");
	shape_file shapefile_industry <- shape_file("../includes/industry/industry.shp");
	shape_file shapefile_office <- shape_file("../includes/office/office.shp");
	shape_file shapefile_park <- shape_file("../includes/park/park.shp");
	shape_file shapefile_school <- shape_file("../includes/school/school.shp");
	shape_file shapefile_supermarket <- shape_file("../includes/supermarket/supermarket.shp");
	shape_file shapefile_roads <- shape_file("../includes/road/roads.shp");
	geometry shape <- envelope(shapefile_roads);

	// Graph road
	graph<geometry, geometry> road_network;
	map<road, float> road_weights;

	// Output the number of casualties
	int casualties;

	init {
	//		create susceptible number: num_of_susceptible;
		create road from: shapefile_roads;
		create home from: shapefile_homes;
		create industry from: shapefile_industry;
		create office from: shapefile_office;
		create park from: shapefile_park;
		create school from: shapefile_school;
		create supermarket from: shapefile_supermarket;
		create susceptible number: num_of_susceptible {
		//			home_point <- any(home);
			int live_in <- rnd(1, 6);
			move_to <- rnd(1, 6);
			loop while: live_in = move_to {
				move_to <- rnd(1, 6);
			}

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

			switch move_to {
				match 1 {
					home_point <- any(home);
				}

				match 2 {
					industry_point <- any(industry);
				}

				match 3 {
					office_point <- any(office);
				}

				match 4 {
					park_point <- any(park);
				}

				match 5 {
					school_point <- any(school);
				}

				match 6 {
					supermarket_point <- any(supermarket);
				}

			}

			perception_distance <- rnd(min_perception_distance, max_perception_distance);
		}
		//
		//		create infectious number: num_of_infectious {
		//			int live_in <- rnd(1, 6);
		//			int move_to <- rnd(1, 6);
		//			switch live_in {
		//				match 1 {
		//					location <- any_location_in(one_of(home));
		//				}
		//
		//				match 2 {
		//					location <- any_location_in(one_of(industry));
		//				}
		//
		//				match 3 {
		//					location <- any_location_in(one_of(office));
		//				}
		//
		//				match 4 {
		//					location <- any_location_in(one_of(park));
		//				}
		//
		//				match 5 {
		//					location <- any_location_in(one_of(school));
		//				}
		//
		//				match 6 {
		//					location <- any_location_in(one_of(supermarket));
		//				}
		//
		//			}
		//
		//			perception_distance <- rnd(min_perception_distance, max_perception_distance);
		//		}

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

	aspect default {
		draw shape width: 4 #m - (3 * speed_coeff) #m color: rgb(55 + 200 * users / capacity, 0, 0);
	}

}

/*
 * People are located in building at the start of the simulation
 */
species building {
	int height;

	aspect geom {
		draw shape color: #grey border: #darkgrey;
	}

	aspect threeD {
		draw shape color: #darkgrey depth: height texture: ["../include/roof_top.png", "../includes/textture5.jpg"];
	}

}

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

species susceptible skills: [moving] {
	float perception_distance;
	float speed <- (2 + rnd(5)) #m;
	int state <- 0;
	float infect_range <- 2 #meter;
	float save_time <- 0.0;
	int count_I <- num_of_infectious;
	int count_S <- num_of_susceptible;
	bool is_infected <- flip(infected_rate);
	bool is_infectedA <- flip(infected_rateA);
	bool have_mask <- flip(mask_rate);
	bool In_or_Ia <- flip(type_I);
	bool N;
	bool A;
	int keeptimeE <- rnd(30, 100);
	int keeptimeI <- rnd(100, 300);
	bool alerted <- true;
	home home_point;
	industry industry_point;
	office office_point;
	park park_point;
	school school_point;
	supermarket supermarket_point;
	int move_to <- rnd(1, 6);

	reflex evacuate when: true {
		switch move_to {
			match 1 {
				do goto target: home_point on: road_network move_weights: road_weights;
			}

			match 2 {
				do goto target: industry_point on: road_network move_weights: road_weights;
			}

			match 3 {
				do goto target: office_point on: road_network move_weights: road_weights;
			}

			match 4 {
				do goto target: park_point on: road_network move_weights: road_weights;
			}

			match 5 {
				do goto target: school_point on: road_network move_weights: road_weights;
			}

			match 6 {
				do goto target: supermarket_point on: road_network move_weights: road_weights;
			}

		}

		if (current_edge != nil) {
			road the_current_road <- road(current_edge);
			the_current_road.users <- the_current_road.users + 1;
		}

	}

	reflex moving {
		if (time != save_time) {
			if (((time - save_time) mod keeptimeE = 0) and state = 1 and In_or_Ia) {
				state <- 2;
			} else if (((time - save_time) mod keeptimeE = 0) and state = 1 and !In_or_Ia) {
				state <- 4;
			} else if ((time - save_time) mod keeptimeI = 0 and (state = 2 or state = 4)) {
				state <- 3;
			} }

			//		write sample(time);
		//		do wander;
	}

	aspect base {
		switch state {
			match 0 {
				draw pyramid(5) color: #white;
				draw sphere(2) at: location + {0, 0, 5} color: #white;
			}

			match 1 {
				draw circle(3) color: #yellow;
			}

			match 2 {
				draw cross(10, 0.5) color: #red;
				draw circle(3) at: location + {0, 0, 5} color: #red;
			}

			match 3 {
				draw circle(3) color: #green;
			}

			match 4 {
				draw circle(3) color: #red;
			}

		}

	}

	reflex attack when: !empty(susceptible at_distance infect_range) and (state = 2 or state = 4) {
		ask susceptible at_distance infect_range {
			if (self.have_mask) {
				N <- flip(infected_rate * 0.5);
				A <- flip(infected_rateA * 0.5);
			}

			if (state = 2) {
				if (self.state = 0 and N) {
					self.state <- 1;
					self.save_time <- time;
				}

			} else {
				if (self.state = 0 and A) {
					self.state <- 1;
					self.save_time <- time;
				}

			}

		}

	} }

species infectious skills: [moving] {
	float perception_distance;
	float speed <- (2 + rnd(5)) #m;
	int state <- 2;
	float infect_range <- 2 #meter;
	float save_time <- 0.0;
	bool have_mask <- flip(mask_rate);
	bool is_infected <- flip(infected_rate);
	int keeptime <- rnd(100, 300);
	home home_point;
	industry industry_point;

	reflex evacuate when: true {
		do goto target: home_point on: road_network move_weights: road_weights;
		if (current_edge != nil) {
			road the_current_road <- road(current_edge);
			the_current_road.users <- the_current_road.users + 1;
		}

	}

	reflex moving {
		if ((time - save_time) mod keeptime = 0 and time != 0 and (state = 2 or state = 4)) {
		//			write sample(time);
			state <- 3;
		}

	}

	aspect base {
		switch state {
			match 2 {
				draw cross(10, 0.5) color: #red;
				draw circle(3) at: location + {0, 0, 5} color: #red;
			}

			match 3 {
				draw circle(3) color: #green;
			}

		}
		//		write sample(length(infectious));
	}

	reflex attack when: !empty(susceptible at_distance infect_range) and state = 2 {
		ask susceptible at_distance infect_range {
			if (have_mask) {
				is_infected <- flip(infected_rate * 0.5);
				if (self.state = 0 and is_infected) {
					self.state <- 1;
					self.save_time <- time;
				}

			} else {
				if (self.state = 0 and is_infected) {
					self.state <- 1;
					self.save_time <- time;
				}

			}

		}

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
			//			species inhabitant;
			species susceptible aspect: base;
			species infectious aspect: base;
		}

		monitor "Number of casualties" value: casualties;
	}

}
