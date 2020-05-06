	model flood

/* Insert your model definition here */
global {
	int num_of_susceptible <- 700;
	int num_of_infectious <- 1;
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
	bool is_light <- true;
	bool is_noon <- false;
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
			
			int live_in <- rnd(1, 6);
			switch live_in {
				match 1 {
					start_point <- any_location_in(one_of(home));
					location <- start_point;
				}

				match 2 {
					start_point <- any_location_in(one_of(industry));
					location <- start_point;
				}

				match 3 {
					start_point <- any_location_in(one_of(office));
					location <- start_point;
				}

				match 4 {
					start_point <- any_location_in(one_of(park));
					location <- start_point;
				}

				match 5 {
					start_point <- any_location_in(one_of(school));
					location <- start_point;
				}

				match 6 {
					start_point <- any_location_in(one_of(supermarket));
					location <- start_point;
				}
			}

			home_point <- any(home);
			industry_point <- any(industry);
			office_point <- any(office);
			park_point <- any(park);
			school_point <- any(school);
			supermarket_point <- any(supermarket);
			perception_distance <- rnd(min_perception_distance, max_perception_distance);
		}
		road_network <- as_edge_graph(road);
		road_weights <- road as_map (each::each.shape.perimeter);
		ask num_of_infectious among susceptible {
		    state <- 2;
		}
	}
	
	reflex end_simulation when: susceptible count (each.state = 0) = 0{
		do pause;
	}
	int hourr <- current_date.hour + 2;
	reflex light_or_noon{
		if(current_date.hour - hourr = 0){
			if(is_light){
				is_light <- false;
				is_noon <- true;
				hourr <- current_date.hour + 2;
			}else{
				is_light <- true;
				is_noon <- false;
				hourr <- current_date.hour + 2;
			}
		}
		write sample(is_light);
	}
	date starting_date <- date([2019, 3, 22, 1, 0, 0]);

//	reflex show_time {
//		write sample(cycle);
//		write sample(time);
//		write sample(current_date);
//		write "===================";
//	}
//
//	reflex clock when: (current_date.hour = 7) and (current_date.minute = 0) {
//		write "------------";
//		write "wake up time";
//		write "------------";
//	}
//
//	reflex endclock when: (current_date.hour = 17) and (current_date.minute = 0) {
//		write "------------";
//		write "end working day";
//		write "------------";
//	}
//
//	reflex crisis when: (current_date.day = 22) and (current_date.hour = 7) {
//		write "------------";
//		write "Flood! Evacuation";
//		write "------------";
//	}
//
//	reflex break when: every(#hour) {
//		write "-------------";
//		write "break time";
//		write "----------";
//	}

}


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
//species building {
//	int height;
//
//	aspect geom {
//		draw shape color: #grey border: #darkgrey;
//	}
//
//	aspect threeD {
//		draw shape color: #darkgrey depth: height texture: ["../include/roof_top.png", "../includes/textture5.jpg"];
//	}
//
//}

species home {
	int nb_total <- 0 update:length(self.people_in_home);
	species people_in_home parent: susceptible schedules: [] { }
	
	aspect default {
		draw shape color: #red border: #black;
	}

    reflex infect_in_buildings when: nb_total > 0 and people_in_home count (each.state = 2) > 0{
		ask (people_in_home where (each.state = 0))
		{
			state <- 2;
		}
	}
	
	reflex let_people_leave when: is_noon{
		release people_in_home where flip(1) as: susceptible in: world 
		{
			
		}

	}

	reflex let_people_enter when: is_light
	{
		capture (susceptible inside self) where (each.end_point = location and each.end_point != nil) as: people_in_home;
	}
	
//	species people_in_home parent: susceptible schedules: [] { }
//	
//	aspect default {
//		draw shape color: #red border: #black;
//	}
//	
//    reflex infect_in_buildings {
//		ask susceptible inside self {
//			if(susceptible count (each.state = 2 or each.state = 4) >= 1){
//				self.state <- 2;
//			}
//		}
//    }
    
//    reflex infect_in_buildings {
//		capture ((susceptible) inside self) as: people_in_home;
//		if(people_in_home count (each.state = 2 or each.state = 4) >= 1){
//			ask people_in_home{
//				self.state <- 2;
//			}
//		}
//    }
}

species industry {
	int nb_total <- 0 update:length(self.people_in_industry);
	species people_in_industry parent: susceptible schedules: [] { }
	
	aspect default {
		draw shape color: #gray border: #black;
	}

    reflex infect_in_buildings when: nb_total > 0 and people_in_industry count (each.state = 2) > 0{
		ask (people_in_industry where (each.state = 0))
		{
			state <- 2;
		}
	}
	
	reflex let_people_leave when: is_noon
	{
		release people_in_industry where flip(1) as: susceptible in: world 
		{
			
		}

	}

	reflex let_people_enter when: is_light
	{
		capture (susceptible inside self) where (each.end_point = location and each.end_point != nil) as: people_in_industry;
	}
//	species people_in_industry parent: susceptible schedules: [] { }
//	aspect default {
//		draw shape color: #gray border: #black;
//	}
//	
//    reflex infect_in_buildings {
//		ask susceptible inside self {
//			if(susceptible count (each.state = 2 or each.state = 4) >= 1){
//				self.state <- 2;
//			}
//		}
//    }

}

species office {
	int nb_total <- 0 update:length(self.people_in_office);
	species people_in_office parent: susceptible schedules: [] { }
	
	aspect default {
		draw shape color: #blue border: #black;
	}

    reflex infect_in_buildings when: nb_total > 0 and people_in_office count (each.state = 2) > 0{
		ask (people_in_office where (each.state = 0))
		{
			state <- 2;
		}
	}
	
	reflex let_people_leave when: is_noon
	{
		release people_in_office where flip(1) as: susceptible in: world 
		{
			
		}

	}

	reflex let_people_enter when: is_light
	{
		capture (susceptible inside self) where (each.end_point = location and each.end_point != nil) as: people_in_office;
	}
//	species people_in_office parent: susceptible schedules: [] { }
//	
//	aspect default {
//		draw shape color: #blue border: #black;
//	}
//
//    reflex infect_in_buildings {
//		ask susceptible inside self {
//			if(susceptible count (each.state = 2 or each.state = 4) >= 1){
//				self.state <- 2;
//			}
//		}
//    }
}

species park {
	int nb_total <- 0 update:length(self.people_in_park);
	species people_in_park parent: susceptible schedules: [] { }
	
	aspect default {
		draw shape color: #green border: #black;
	}

    reflex infect_in_buildings when: nb_total > 0 and people_in_park count (each.state = 2) > 0 {
		ask (people_in_park where (each.state = 0))
		{
			state <- 2;
		}
	}
	
	reflex let_people_leave when: is_noon
	{
		release people_in_park where flip(1) as: susceptible in: world 
		{
			
		}

	}

	reflex let_people_enter when: is_light
	{
		capture (susceptible inside self) where (each.end_point = location and each.end_point != nil) as: people_in_park;
	}
//	species people_in_park parent: susceptible schedules: [] { }
//	
//	aspect default {
//		draw shape color: #green border: #black;
//	}
//
//    reflex infect_in_buildings {
//		ask susceptible inside self {
//			if(susceptible count (each.state = 2 or each.state = 4) >= 1){
//				self.state <- 2;
//			}
//		}
//    }
}

species school {
	int nb_total update:length(self.people_in_school);
	species people_in_school parent: susceptible schedules: [] { }
	
	aspect default {
		draw shape color: #yellow border: #black;
	}

    reflex infect_in_buildings when: nb_total > 0 and people_in_school count (each.state = 2) > 0{
		ask (people_in_school where (each.state = 0))
		{
			state <- 2;
		}
	}
	
	reflex let_people_leave when: is_noon
	{
		release people_in_school where flip(1) as: susceptible in: world 
		{
			
		}

	}

	reflex let_people_enter when: is_light
	{
		capture (susceptible inside self) where (each.end_point = location and each.end_point != nil) as: people_in_school;
	}
//	species people_in_school parent: susceptible schedules: [] { }
//	
//	aspect default {
//		draw shape color: #yellow border: #black;
//	}
//
//    reflex infect_in_buildings {
//		ask susceptible inside self {
//			if(susceptible count (each.state = 2 or each.state = 4) >= 1){
//				self.state <- 2;
//			}
//		}
//    }
}

species supermarket {
	int nb_total update:length(self.people_in_supermarket);
	species people_in_supermarket parent: susceptible schedules: [] { }
	
	aspect default {
		draw shape color: #violet border: #black;
	}

    reflex infect_in_buildings when: nb_total > 0 and (people_in_supermarket count (each.state = 2) > 0 ){
		ask (people_in_supermarket where (each.state = 0))
		{
			state <- 2;
		}
	}
	
	reflex let_people_leave when: is_noon
	{
		release people_in_supermarket where flip(1) as: susceptible in: world 
		{
			
		}

	}

	reflex let_people_enter when: is_light
	{
		capture (susceptible inside self) where (each.end_point = location and each.end_point != nil) as: people_in_supermarket;
	}
}
    


species susceptible skills: [moving] {
	point start_point;
	point end_point <- nil;
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
	bool kid_or_adult <- flip(0.5);
	bool industry_or_office <- flip(0.5);
	
	reflex chooosee when: end_point = nil{
		if(kid_or_adult){
			end_point <- school_point.location;
		}else{
			end_point <- industry_or_office = true ? industry_point.location : office_point.location;
		}
	}
	
	reflex evacuate when: end_point != nil {
			if(is_light){
				if(end_point != location){
					do goto target: end_point on: road_network move_weights: road_weights;
				}
			}else if (is_noon){
				if(start_point != location){
					do goto target: start_point on: road_network move_weights: road_weights;
				}
			}

		if (current_edge != nil) {
			road the_current_road <- road(current_edge);
			the_current_road.users <- the_current_road.users + 1;
		}

	}


	aspect base {
		switch state {
			match 0 {
				draw pyramid(8) color: #white;
				draw sphere(4) at: location + {0, 0, 5} color: #white;
			}

			match 1 {
				draw circle(3) color: #yellow;
			}

			match 2 {
				draw cross(10, 0.5) color: #red;
				draw circle(15) at: location + {0, 0, 5} color: #red;
			}

			match 3 {
				draw circle(3) color: #green;
			}

			match 4 {
				draw circle(3) color: #red;
			}

		}

	}
}

experiment "Run" {
	float minimum_cycle_duration <- 0.1;
	parameter "Number of people" var: num_of_susceptible min: 100 max: 20000 category: "Initialization";
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

		monitor "nb_infect" value: susceptible count(each.state = 2) + people_in_home count (each.state = 2)+ people_in_industry count (each.state = 2)+ people_in_office count (each.state = 2)+ people_in_park count (each.state = 2)+ people_in_school count (each.state = 2)+ people_in_supermarket count (each.state = 2);
		monitor "nb" value: susceptible count(each.state = 0)+ people_in_home count (each.state = 0)+ people_in_industry count (each.state = 0)+ people_in_office count (each.state = 0)+ people_in_park count (each.state = 0)+ people_in_school count (each.state = 0)+ people_in_supermarket count (each.state = 0);
	}

}
