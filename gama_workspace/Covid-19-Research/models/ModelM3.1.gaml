/***
* Name: NewModel
* Author: DUONG
* Description: 
* Tags: Tag1, Tag2, TagN
***/
model ModelM23

/* Insert your model definition here */
global {
	int num_of_susceptible <- 700;
	int num_of_infectious <- 1;
	float mask_rate <- 0.5;
	bool have_mask <- false;
	float type_I <- 0.7;
	float infected_rate <- 1.0;
	float infected_rateA <- 0.55;
	// Time step to represent very short term movement (for congestion)
	float step <- 20 #mn;
	int nb_of_people;
	int nb_infect <- 0;
	bool lockdown <- false;
	float lockdown_rate <- 0.5;
	bool close_school <- false;
	float close_school_rate <- 0.3;
	// Represents the capacity of a road indicated as: number of inhabitant per #m of road
	float road_density;
	bool child_containment <- false;
	bool adult_containment <- false;
	bool elder_containment <- false;
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
	geometry
	shape <- envelope(envelope(shapefile_homes) + envelope(shapefile_industry) + envelope(shapefile_office) + envelope(shapefile_park) + envelope(shapefile_school) + envelope(shapefile_supermarket));

	// Graph road
	graph<geometry, geometry> road_network;
	map<road, float> road_weights;
	int current_hour update: (time / #hour) mod 24;
	int nb_day <- 0;

	init {
	//		create susceptible number: num_of_susceptible;
		create road from: shapefile_roads;
		create home from: shapefile_homes;
		create industry from: shapefile_industry;
		create office from: shapefile_office;
		create park from: shapefile_park;
		create school from: shapefile_school;
		create supermarket from: shapefile_supermarket;
		loop i over: home {
			int nb_adults <- 2;
			int nb_childs <- rnd(0, 3);
			int nb_olds <- flip(0.5) ? 1 : 0;
			create susceptible number: 1 {
				start_point <- any_location_in(one_of(i));
				location <- start_point;
				industry_point <- one_of(industry);
				office_point <- one_of(office);
				park_point <- one_of(park);
				school_point <- one_of(school);
				supermarket_point <- one_of(supermarket);
				gender <- true;
				state <- 0;
				type <- 0;
			}

			create susceptible number: 1 {
				start_point <- any_location_in(one_of(i));
				location <- start_point;
				industry_point <- one_of(industry);
				office_point <- one_of(office);
				park_point <- one_of(park);
				school_point <- one_of(school);
				supermarket_point <- one_of(supermarket);
				gender <- false;
				state <- 0;
				type <- 1;
			}

			create susceptible number: nb_childs {
				start_point <- any_location_in(one_of(i));
				location <- start_point;
				industry_point <- one_of(industry);
				office_point <- one_of(office);
				park_point <- one_of(park);
				school_point <- one_of(school);
				supermarket_point <- one_of(supermarket);
				gender <- flip(0.5);
				state <- 0;
				type <- 2;
			}

			create susceptible number: nb_olds {
				start_point <- any_location_in(one_of(i));
				location <- start_point;
				industry_point <- one_of(industry);
				office_point <- one_of(office);
				park_point <- one_of(park);
				school_point <- one_of(school);
				supermarket_point <- one_of(supermarket);
				gender <- flip(0.5);
				state <- 0;
				type <- 3;
			}

		}

		road_network <- as_edge_graph(road);
		ask num_of_infectious among susceptible {
			state <- 2;
			save_time <- nb_day;
		}

		nb_of_people <- length(susceptible);
	}

	bool is_workhour <- false;
	bool is_homehour <- false;
	bool is_light <- false;
	bool is_noon <- false;

	reflex light_or_noonn {
		if (current_hour > 4 and current_hour < 16) {
			is_light <- true;
			is_noon <- false;
		} else {
			is_light <- false;
			is_noon <- true;
		}

	}

	reflex splt {
		if (current_hour = 7) {
			is_workhour <- true;
			is_homehour <- false;
		} else if (current_hour = 19) {
			is_workhour <- false;
			is_homehour <- true;
		}

		if (nb_infect < susceptible count (each.state = 2)) {
			nb_infect <- susceptible count (each.state = 2);
		}

	}

	bool check <- false;

	reflex cal_day {
		if (current_hour mod 24 = 0 and !check) {
			nb_day <- nb_day + 1;
			check <- true;
		}

		if (current_hour = 1) {
			check <- false;
		}

	}

	reflex end_simulation when: susceptible count (each.state = 3) = nb_of_people {
		do pause;
	}

	reflex light_or_noon {
		write sample(current_hour);
	}

}

/*
 * The roads inhabitant will use to evacuate. Roads compute the congestion of road segment
 * accordin to the Underwood function.
 */
species road {

// Number of user on the road section
	int users;
	float capacity <- 1 + shape.perimeter / 30;
	float speed_coeff <- 1.0;

	aspect default {
		draw shape color: #black depth: 3.0;
	}

}

species home {
	int nb_total <- 0 update: length(self.people_in_home);
	species people_in_home parent: susceptible schedules: [] {
	}

	aspect default {
		draw shape color: #lightgreen border: #black;
	}

	reflex test1 {
		do test();
	}

	action test {
		if (is_light and !is_workhour) {
			capture (susceptible inside self) where (each.end_point != nil) as: people_in_home;
			do inf();
		} else if (is_light and is_workhour) {
			release people_in_home where flip(1) as: susceptible in: world {
			}

		} else if (is_noon and !is_homehour) {
			capture (susceptible inside self) where (each.end_point != nil) as: people_in_home;
			do inf();
		} else if (is_noon and is_homehour) {
			release people_in_home where flip(1) as: susceptible in: world {
			}

		} }

	action inf {
		if (nb_total > 0 and (people_in_home count (each.state = 2) > 0)) {
			ask (people_in_home where (each.state != 2 and each.state != 3 and each.state != 1)) {
				if (have_mask) {
					if (flip(infected_rate * mask_rate)) {
						state <- 1;
						save_time <- nb_day;
					}

				} else {
					if (flip(infected_rate)) {
						state <- 1;
						save_time <- nb_day;
					}

				}

			}

		}

	} }

species industry {
	int nb_total <- 0 update: length(self.people_in_industry);
	species people_in_industry parent: susceptible schedules: [] {
	}

	aspect default {
		draw shape color: #gray border: #black;
	}

	reflex test1 {
		do test();
	}

	action test {
		if (is_light and !is_workhour) {
			capture (susceptible inside self) where (each.end_point != nil) as: people_in_industry;
			do inf();
		} else if (is_light and is_workhour) {
			release people_in_industry where flip(1) as: susceptible in: world {
			}

		} else if (is_noon and !is_homehour) {
			capture (susceptible inside self) where (each.end_point != nil) as: people_in_industry;
			do inf();
		} else if (is_noon and is_homehour) {
			release people_in_industry where flip(1) as: susceptible in: world {
			}

		} }

	action inf {
		if (nb_total > 0 and (people_in_industry count (each.state = 2) > 0)) {
			ask (people_in_industry where (each.state != 2 and each.state != 3 and each.state != 1)) {
				if (have_mask) {
					if (flip(infected_rate * mask_rate)) {
						state <- 1;
						save_time <- nb_day;
					}

				} else {
					if (flip(infected_rate)) {
						state <- 1;
						save_time <- nb_day;
					}

				}

			}

		}

	} }

species office {
	int nb_total <- 0 update: length(self.people_in_office);
	species people_in_office parent: susceptible schedules: [] {
	}

	aspect default {
		draw shape color: #blue border: #black;
	}

	reflex test1 {
		do test();
	}

	action test {
		if (is_light and !is_workhour) {
			capture (susceptible inside self) where (each.end_point != nil) as: people_in_office;
			do inf();
		} else if (is_light and is_workhour) {
			release people_in_office where flip(1) as: susceptible in: world {
			}

		} else if (is_noon and !is_homehour) {
			capture (susceptible inside self) where (each.end_point != nil) as: people_in_office;
			do inf();
		} else if (is_noon and is_homehour) {
			release people_in_office where flip(1) as: susceptible in: world {
			}

		} }

	action inf {
		if (nb_total > 0 and (people_in_office count (each.state = 2) > 0)) {
			ask (people_in_office where (each.state != 2 and each.state != 3 and each.state != 1)) {
				if (have_mask) {
					if (flip(infected_rate * mask_rate)) {
						state <- 1;
						save_time <- nb_day;
					}

				} else {
					if (flip(infected_rate)) {
						state <- 1;
						save_time <- nb_day;
					}

				}

			}

		}

	} }

species park {
	int nb_total <- 0 update: length(self.people_in_park);
	species people_in_park parent: susceptible schedules: [] {
	}

	aspect default {
		draw shape color: #green border: #black;
	}

	reflex test1 {
		do test();
	}

	action test {
		if (is_light and !is_workhour) {
			capture (susceptible inside self) where (each.end_point != nil) as: people_in_park;
			do inf();
		} else if (is_light and is_workhour) {
			release people_in_park where flip(1) as: susceptible in: world {
			}

		} else if (is_noon and !is_homehour) {
			capture (susceptible inside self) where (each.end_point != nil) as: people_in_park;
			do inf();
		} else if (is_noon and is_homehour) {
			release people_in_park where flip(1) as: susceptible in: world {
			}

		} }

	action inf {
		if (nb_total > 0 and (people_in_park count (each.state = 2) > 0)) {
			ask (people_in_park where (each.state != 2 and each.state != 3 and each.state != 1)) {
				if (have_mask) {
					if (flip(infected_rate * mask_rate)) {
						state <- 1;
						save_time <- nb_day;
					}

				} else {
					if (flip(infected_rate)) {
						state <- 1;
						save_time <- nb_day;
					}

				}

			}

		}

	} }

species school {
	int nb_total update: length(self.people_in_school);
	species people_in_school parent: susceptible schedules: [] {
	}

	aspect default {
		draw shape color: #yellow border: #black;
	}

	reflex test1 {
		do test();
	}

	action test {
		if (is_light and !is_workhour) {
			capture (susceptible inside self) where (each.end_point != nil) as: people_in_school;
			do inf();
		} else if (is_light and is_workhour) {
			release people_in_school where flip(1) as: susceptible in: world {
			}

		} else if (is_noon and !is_homehour) {
			capture (susceptible inside self) where (each.end_point != nil) as: people_in_school;
			do inf();
		} else if (is_noon and is_homehour) {
			release people_in_school where flip(1) as: susceptible in: world {
			}

		} }

	action inf {
		if (nb_total > 0 and (people_in_school count (each.state = 2) > 0)) {
			ask (people_in_school where (each.state != 2 and each.state != 3 and each.state != 1)) {
				if (have_mask) {
					if (flip(infected_rate * mask_rate)) {
						state <- 1;
						save_time <- nb_day;
					}

				} else {
					if (flip(infected_rate)) {
						state <- 1;
						save_time <- nb_day;
					}

				}

			}

		}

	} }

species supermarket {
	int nb_total update: length(self.people_in_supermarket);
	species people_in_supermarket parent: susceptible schedules: [] {
	}

	aspect default {
		draw shape color: #violet border: #black;
	}

	reflex test1 {
		do test();
	}

	action test {
		if (is_light and !is_workhour) {
			capture (susceptible inside self) where (each.end_point != nil) as: people_in_supermarket;
			do inf();
		} else if (is_light and is_workhour) {
			release people_in_supermarket where flip(1) as: susceptible in: world {
			}

		} else if (is_noon and !is_homehour) {
			capture (susceptible inside self) where (each.end_point != nil) as: people_in_supermarket;
			do inf();
		} else if (is_noon and is_homehour) {
			release people_in_supermarket where flip(1) as: susceptible in: world {
			}

		} }

	action inf {
		if (nb_total > 0 and (people_in_supermarket count (each.state = 2) > 0)) {
			ask (people_in_supermarket where (each.state != 2 and each.state != 3 and each.state != 1)) {
				if (have_mask) {
					if (flip(infected_rate * mask_rate)) {
						state <- 1;
						save_time <- nb_day;
					}

				} else {
					if (flip(infected_rate)) {
						state <- 1;
						save_time <- nb_day;
					}

				}

			}

		}

	} }

species susceptible skills: [moving] {
	point start_point;
	point end_point <- nil;
	float speed <- (2 + rnd(5)) #m;
	int state;
	industry industry_point;
	office office_point;
	park park_point;
	school school_point;
	supermarket supermarket_point;
	bool kid_or_adult <- flip(0.5);
	bool industry_or_office <- flip(0.5);
	bool work_or_play <- flip(0.4);
	bool gender;
	int type;
	int staying <- 0;
	int save_time;
	int keeptimeE <- rnd(3,7);
	int keeptimeI <- rnd(10,15);

	reflex moving {
		if (nb_day != save_time) {
			if (((nb_day - save_time) mod keeptimeE = 0) and state = 1) {
				state <- 2;
				save_time <- nb_day;
			} else if (((nb_day - save_time) mod keeptimeI = 0) and state = 2) {
				state <- 3;
			}

		}

	}

	reflex chooosee when: end_point = nil {
		switch type {
			match 0 {
				end_point <- industry_or_office ? any_location_in(industry_point) : any_location_in(office_point);
			}

			match 1 {
				end_point <- work_or_play ? (industry_or_office ? any_location_in(industry_point) : any_location_in(office_point)) : any_location_in(supermarket_point);
			}

			match 2 {
				end_point <- any_location_in(school_point);
			}

			match 3 {
				end_point <- any_location_in(park_point);
			}

		}

	}

	reflex evacuate_child when: end_point != nil {
		if (lockdown and (nb_infect / nb_of_people >= lockdown_rate)) {
			do goto target: start_point on: road_network;
		} else {
			if (close_school and type = 2) {
				do goto target: start_point on: road_network;
			} else {
				if (child_containment and type = 2) {
					do goto target: start_point on: road_network;
				} else if (type = 2) {
					if (is_workhour) {
						do goto target: end_point on: road_network;
					} else if (is_homehour) {
						do goto target: start_point on: road_network;
					}

				}

			}

		}

	}

	reflex evacuate_elder when: end_point != nil {
		if (lockdown and (nb_infect / nb_of_people >= lockdown_rate)) {
			do goto target: start_point on: road_network;
		} else {
			if (elder_containment and type = 3) {
				do goto target: start_point on: road_network;
			} else if (type = 3) {
				if (is_workhour) {
					do goto target: end_point on: road_network;
				} else if (is_homehour) {
					do goto target: start_point on: road_network;
				}

			}

		}

	}

	reflex evacuate_adult when: end_point != nil {
		if (lockdown and (nb_infect / nb_of_people >= lockdown_rate)) {
			do goto target: start_point on: road_network;
		} else {
			if (adult_containment and (type = 0 or type = 1)) {
				do goto target: start_point on: road_network;
			} else if (type = 0 or type = 1) {
				if (is_workhour) {
					do goto target: end_point on: road_network;
				} else if (is_homehour) {
					do goto target: start_point on: road_network;
				}

			}

		}

	}

	aspect base {
		switch state {
			match 0 {
				switch type {
					match 0 {
						draw pyramid(8) color: #green;
						draw sphere(6) at: location + {0, 0, 5} color: #green;
					}

					match 1 {
						draw pyramid(8) color: #pink;
						draw sphere(6) at: location + {0, 0, 5} color: #pink;
					}

					match 2 {
						draw pyramid(8) color: #yellow;
						draw sphere(6) at: location + {0, 0, 5} color: #yellow;
					}

					match 3 {
						draw pyramid(8) color: #blue;
						draw sphere(6) at: location + {0, 0, 5} color: #blue;
					}

				}

			}

			match 1 {
				draw pyramid(8) color: #black;
				draw sphere(15) at: location + {0, 0, 5} color: #black;
			}

			match 2 {
				draw pyramid(8) color: #red;
				draw sphere(15) at: location + {0, 0, 5} color: #red;
			}

			match 3 {
				switch type {
					match 0 {
						draw pyramid(8) color: #green;
						draw sphere(6) at: location + {0, 0, 5} color: #green;
					}

					match 1 {
						draw pyramid(8) color: #pink;
						draw sphere(6) at: location + {0, 0, 5} color: #pink;
					}

					match 2 {
						draw pyramid(8) color: #yellow;
						draw sphere(6) at: location + {0, 0, 5} color: #yellow;
					}

					match 3 {
						draw pyramid(8) color: #blue;
						draw sphere(6) at: location + {0, 0, 5} color: #blue;
					}

				}

			}

		}

	}

}

experiment "Run" {
	float minimum_cycle_duration <- 0.1;
	parameter "Number of people" var: num_of_susceptible min: 100 max: 20000 category: "Initialization";
	parameter "Infected rate" var: infected_rate min: 0.0 max: 1.0;
	parameter "Condition to lockdown" var: lockdown_rate min: 0.0 max: 1.0;
	parameter "Lockdown" var: lockdown init: false;
	//	parameter "Condition to wear mask" var: mask_rate min: 0.0 max: 1.0;
	parameter "Wear mask" var: have_mask init: false;
	//	parameter "Condition to close school" var: close_school_rate min: 0.0 max: 1.0;
	parameter "Child" var: child_containment init: false category: "Containment by ages";
	parameter "Adult" var: adult_containment init: false category: "Containment by ages";
	parameter "Elder" var: elder_containment init: false category: "Containment by ages";
	output {
		display my_display type: opengl {
			species road;
			species home;
			species industry;
			species office;
			species park;
			species school;
			species supermarket;
			species susceptible aspect: base;
		}

		monitor "nb_infect" value: susceptible count (each.state = 2);
		monitor "day" value: nb_day;
		monitor "nb_people" value: nb_of_people;
		monitor "nb_of_E" value: susceptible count (each.state = 1);
		monitor "nb_of_R" value: susceptible count (each.state = 3);
	}

}
