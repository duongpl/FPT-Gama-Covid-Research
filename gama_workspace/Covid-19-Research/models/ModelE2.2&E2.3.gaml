/***
* Name: ModelE22E23
* Author: DUONG
* Description: 
* Tags: Tag1, Tag2, TagN
***/

model ModelE22E23

/* Insert your model definition here */
global {
	int num_of_susceptible <- 700;
	int num_of_infectious <- 1;
	float mask_rate <- 0.8;
	float type_I <- 0.7;
	float infected_rate <- 1.0;
	float infected_rateA <- 0.55;
	// Time step to represent very short term movement (for congestion)
	float step <- 1 #mn;
	int nb_of_people;
	int nb_infect <- 0;

	// Represents the capacity of a road indicated as: number of inhabitant per #m of road
	float road_density;

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
	geometry shape <- envelope(envelope(shapefile_homes) + envelope(shapefile_industry)+ envelope(shapefile_office)+ envelope(shapefile_park)+ envelope(shapefile_school)+ envelope(shapefile_supermarket));

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
				int nb_childs <- rnd(0,3);
				int nb_olds <- flip(0.5) ? 1:0;
				create susceptible number: 1{
					start_point <- any_location_in(one_of(i));
					location <- start_point;
					industry_point <- one_of(industry);
					office_point <- one_of(office);
					park_point <- one_of(park);
					school_point <- one_of(school);
					supermarket_point <- one_of(supermarket);
					gender <- true;
					age <- rnd(23,55);
					state <- 0;
					type <- 0;
				}
				create susceptible number: 1{
					start_point <- any_location_in(one_of(i));
					location <- start_point;
					industry_point <- one_of(industry);
					office_point <- one_of(office);
					park_point <- one_of(park);
					school_point <- one_of(school);
					supermarket_point <- one_of(supermarket);
					gender <- false;
					age <- rnd(23,55);
					state <- 1;
					type <- 1;
				}
				create susceptible number: nb_childs{
					start_point <- any_location_in(one_of(i));
					location <- start_point;
					industry_point <- one_of(industry);
					office_point <- one_of(office);
					park_point <- one_of(park);
					school_point <- one_of(school);
					supermarket_point <- one_of(supermarket);
					age <- rnd(1,22);
					gender <- flip(0.5);
					state <- 2;
					type <- 2;
				}
				create susceptible number: nb_olds{
					start_point <- any_location_in(one_of(i));
					location <- start_point;
					industry_point <- one_of(industry);
					office_point <- one_of(office);
					park_point <- one_of(park);
					school_point <- one_of(school);
					supermarket_point <- one_of(supermarket);
					gender <- flip(0.5);
					age <- rnd(56,90);
					state <- 3;
					type <- 3;
				}
			}

		road_network <- as_edge_graph(road);
//		road_weights <- road as_map (each::each.shape.perimeter);
		ask num_of_infectious among susceptible {
			state <- 4;
		}
		nb_of_people <- length(susceptible);
	}
	
	bool check <- false;
	reflex cal_day{
		if(current_hour mod 24 = 0 and !check){
			nb_day <- nb_day + 1;
			check <- true;
		}if(current_hour = 1){
			check <- false;
		}
	}
	
	reflex end_simulation when: susceptible count (each.state = 4) = nb_of_people{
		do pause;
	}

	reflex light_or_noon{
		write sample(current_hour);
	}
	reflex splt{
		if(nb_infect < susceptible count(each.state =4)){
			nb_infect <- susceptible count(each.state =4);
		}
	}
	date starting_date <- date([2019, 3, 22, 6, 0, 0]);
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
//	reflex update_weights {
//		speed_coeff <- max(0.05, exp(-users / capacity));
//		road_weights[self] <- shape.perimeter / speed_coeff;
//		users <- 0;
//	}

	aspect default {
//		draw shape width: 4 #m - (3 * speed_coeff) #m color: rgb(55 + 200 * users / capacity, 0, 0);
		draw shape color: # black depth: 3.0;
	}

}

species home {
	int nb_total <- 0 update:length(self.people_in_home);
	species people_in_home parent: susceptible schedules: [] { }
	
	aspect default {
		draw shape color: #lightgreen border: #black;
	}

	reflex checking {
		ask (susceptible inside self){
			staying <- staying + 1;
		}
	}
	
	reflex capture{
		capture (susceptible inside self) where (each.staying >= 45 and each.end_point != nil) as: people_in_home;
	}
	
	reflex infect{
		if(nb_total > 0 and (people_in_home count (each.state = 4) > 0 )){
			ask (people_in_home where (each.state = 0 or each.state = 1 or each.state = 2 or each.state = 3))
			{
				state <- 4;
			}
		}
	}
	
	reflex release when: current_date.minute = 0{
		release people_in_home where flip(1) as: susceptible in: world {
			staying <- 0;
		}
	}

}

species industry {
	int nb_total <- 0 update:length(self.people_in_industry);
	species people_in_industry parent: susceptible schedules: [] { }
	
	aspect default {
		draw shape color: #gray border: #black;
	}

	reflex checking {
		ask (susceptible inside self){
			staying <- staying + 1;
		}
	}
	
	reflex capture{
		capture (susceptible inside self) where (each.staying >= 45 and each.end_point != nil) as: people_in_industry;
	}
	
	reflex infect{
		if(nb_total > 0 and (people_in_industry count (each.state = 4) > 0 )){
			ask (people_in_industry where (each.state = 0 or each.state = 1 or each.state = 2 or each.state = 3))
			{
				state <- 4;
			}
		}
	}
	
	reflex release when: current_date.minute = 0{
		release people_in_industry where flip(1) as: susceptible in: world {
			staying <- 0;
		}
	}


}

species office {
	int nb_total <- 0 update:length(self.people_in_office);
	species people_in_office parent: susceptible schedules: [] { }
	
	aspect default {
		draw shape color: #blue border: #black;
	}

	reflex checking {
		ask (susceptible inside self){
			staying <- staying + 1;
		}
	}
	
	reflex capture{
		capture (susceptible inside self) where (each.staying >= 45 and each.end_point != nil) as: people_in_office;
	}
	
	reflex infect{
		if(nb_total > 0 and (people_in_office count (each.state = 4) > 0 )){
			ask (people_in_office where (each.state = 0 or each.state = 1 or each.state = 2 or each.state = 3))
			{
				state <- 4;
			}
		}
	}
	
	reflex release when: current_date.minute = 0{
		release people_in_office where flip(1) as: susceptible in: world {
			staying <- 0;
		}
	}

}

species park {
	int nb_total <- 0 update:length(self.people_in_park);
	species people_in_park parent: susceptible schedules: [] { }
	
	aspect default {
		draw shape color: #green border: #black;
	}

	
	reflex checking {
		ask (susceptible inside self){
			staying <- staying + 1;
		}
	}
	
	reflex capture{
		capture (susceptible inside self) where (each.staying >= 45 and each.end_point != nil) as: people_in_park;
	}
	
	reflex infect{
		if(nb_total > 0 and (people_in_park count (each.state = 4) > 0 )){
			ask (people_in_park where (each.state = 0 or each.state = 1 or each.state = 2 or each.state = 3))
			{
				state <- 4;
			}
		}
	}
	
	reflex release when: current_date.minute = 0{
		release people_in_park where flip(1) as: susceptible in: world {
			staying <- 0;
		}
	}
}

species school {
	int nb_total update:length(self.people_in_school);
	species people_in_school parent: susceptible schedules: [] { }
	
	aspect default {
		draw shape color: #yellow border: #black;
	}
	
	reflex checking {
		ask (susceptible inside self){
			staying <- staying + 1;
		}
	}
	
	reflex capture{
		capture (susceptible inside self) where (each.staying >= 45 and each.end_point != nil) as: people_in_school;
	}
	
	reflex infect{
		if(nb_total > 0 and (people_in_school count (each.state = 4) > 0 )){
			ask (people_in_school where (each.state = 0 or each.state = 1 or each.state = 2 or each.state = 3))
			{
				state <- 4;
			}
		}
	}
	
	reflex release when: current_date.minute = 0{
		release people_in_school where flip(1) as: susceptible in: world {
			staying <- 0;
		}
	}

}

species supermarket {
	int nb_total update:length(self.people_in_supermarket);
	species people_in_supermarket parent: susceptible schedules: [] { }
	
	aspect default {
		draw shape color: #violet border: #black;
	}
	
	reflex checking {
		ask (susceptible inside self){
			staying <- staying + 1;
		}
	}
	
	reflex capture{
		capture (susceptible inside self) where (each.staying >= 45 and each.end_point != nil) as: people_in_supermarket;
	}
	
	reflex infect{
		if(nb_total > 0 and (people_in_supermarket count (each.state = 4) > 0 )){
			ask (people_in_supermarket where (each.state = 0 or each.state = 1 or each.state = 2 or each.state = 3))
			{
				state <- 4;
			}
		}
	}
	
	reflex release when: current_date.minute = 0{
		release people_in_supermarket where flip(1) as: susceptible in: world {
			staying <- 0;
		}
	}

}


species susceptible skills: [moving] {
	point start_point;
	point end_point <- nil;
	float speed <- (2 + rnd(5)) #m;
	int state <- 0;
	industry industry_point;
	office office_point;
	park park_point;
	school school_point;
	supermarket supermarket_point;
	bool kid_or_adult <- flip(0.5);
	bool industry_or_office <- flip(0.5);
	bool work_or_play <- flip(0.4);
	bool gender;
	int age;
	int type;
	int staying <- 0;
	
	reflex chooosee when: end_point = nil{
		switch type{
			match 0{
				end_point <- industry_or_office ? any_location_in(industry_point) : any_location_in(office_point);
			}
			match 1{
				end_point <- work_or_play ? (industry_or_office ? any_location_in(industry_point) : any_location_in(office_point)) : any_location_in(supermarket_point);
			}
			match 2{
				end_point <- any_location_in(school_point);
			}
			match 3{
				end_point <- any_location_in(park_point);
			}
		}
	}
	
	reflex evacuate when: end_point != nil {
			if(type = 0)
			{
				if(current_hour = 7){
					do goto target: end_point on: road_network ;
				}else if(current_hour = 17){
					do goto target: start_point on: road_network ;
				}
			}else if(type = 1){
				if(work_or_play and current_hour = 7){
					do goto target: end_point on: road_network ;
				}else if(work_or_play and current_hour = 17){
					do goto target: start_point on: road_network ;
				}else if(!work_or_play and current_hour = 8){
					do goto target: end_point on: road_network ;
				}else if(!work_or_play and current_hour = rnd(9,17)){
					do goto target: start_point on: road_network ;
				}
			}else if(type = 2){
				if(current_hour = 7){
					do goto target: end_point on: road_network ;
				}else if(current_hour = 16){
					do goto target: any_location_in(park_point) on: road_network ;
				}else if(current_hour = 17){
					do goto target: start_point on: road_network ;
				}
			}else if(type = 3){
				if(current_hour = rnd(9,14)){
					do goto target: end_point on: road_network ;
				}else if(current_hour = rnd(15,17)){
					do goto target: start_point on: road_network ;
				}
			}

//		if (current_edge != nil) {
//			road the_current_road <- road(current_edge);
//			the_current_road.users <- the_current_road.users + 1;
//		}
	}


	aspect base {
		switch state {
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
			match 4 {
				draw pyramid(8) color: #red;
				draw circle(14) at: location + {0, 0, 5} color: #red;
			}
		}
	}
}
experiment "Run" {
	float minimum_cycle_duration <- 0.1;
	parameter "Number of people" var: num_of_susceptible min: 100 max: 20000 category: "Initialization";
	output {
//		display my_display type: opengl {
//			species road;
//			species home;
//			species industry;
//			species office;
//			species park;
//			species school;
//			species supermarket;
//			species susceptible aspect: base;
//		}
		
		display epidemic_spread_E23 refresh: every(5 #cycle){
			chart "epidemic spread" type: series {
				data value: nb_infect  legend: "Number of infected people" color:#red;
			}
		}
        display "E2.2-1" {
        	chart "the population distribution in terms of age" type: histogram {
        		datalist (distribution_of(susceptible collect each.age,20,1,90) at "legend") 
            		value:(distribution_of(susceptible collect each.age,20,1,90) at "values");      
        	}
    	}
        display "E2.2-2" {
        	chart "the ratio male-female" type: pie {
				datalist ["Male","Female"] value: [susceptible count (each.gender),susceptible count (!each.gender)] color: [#red,#blue];
        	}
		}
//		monitor "nb_infect" value: nb_infect;
//		monitor "day" value: nb_day;
//		monitor "nb_people" value: nb_of_people;
	}

}