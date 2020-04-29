/**
* Name: TrafficMultiModal
* Author: kevinchapuis
* Description: 
* Tags: Tag1, Tag2, TagN
*/

model TrafficMultiModal

global {
	
	float perception_distance <- 60#m;
	
	float step <- 10#s;
	
	float disaster_size <- 30#m;
	int casualties;
	int evacuates;
	
	int nb_car <- 0;
	float car_speed <- 20#km/#h;
	int nb_people <- 200;
	float pedestrian_speed <- 5#km/#h;
	float walking_distance <- 100#m;
	
	file shapefile_roads  <- file("../includes/clean_roads.shp") ;
	file shapefile_buildings  <-  file("../includes/buildings.shp");
	
	file shapefile_pedestrian <- file("../includes/pedestrian.shp");
	
	file shapefile_evacuation <- file("../includes/evacuation.shp");
	
	graph<geometry> road_network;
	graph<geometry> pedestrian_network;
	map<road,float> road_weights <- [];
	
	geometry shape <- envelope(envelope(shapefile_buildings) 
		union envelope(shapefile_roads) union envelope(shapefile_evacuation)
	);

	init{
		
		
		create evacuation from:shapefile_evacuation;
		
		// BUILDING
		create building from:shapefile_buildings;
		
		// ROAD
		create road from: shapefile_roads {
				nbLanes <- building closest_to self distance_to location > 3#m ? 2 : 1;
				capacity <- 1 + nbLanes * shape.perimeter/30;
				
		}
/* 		list<geometry> cleaned_road_shp <- clean_network(shapefile_roads.contents,1#m,true,true);
		loop c_road over:cleaned_road_shp where (empty(building overlapping each)){
			create road {
				shape <- c_road;
				nbLanes <- building closest_to self distance_to location > 3#m ? 2 : 1;
				capacity <- 1 + nbLanes * shape.perimeter/30;
				create road {
						shape <- polyline(reverse(myself.shape.points));
						nbLanes <- myself.nbLanes;
						capacity <- myself.capacity;
					}
			}
		}*/
		road_network <- (as_edge_graph(road));
		road_weights <- road as_map (each::each.shape.perimeter);
		
		create corridor from:shapefile_pedestrian;
		pedestrian_network <- as_edge_graph(corridor);
		
		// CAR & PEOPLE
		create car number:nb_car;
		list<car> the_cars <- list(car);
		create people number:nb_people{
			my_car <- one_of(the_cars);
			if(my_car != nil){
				the_cars >- my_car;
				my_car.location <- any_location_in(self.home_place);
			}
		}
		
	}
	
	reflex update_weights {
		road_weights <- road as_map (each::each.shape.perimeter * exp(-each.nb_cars/each.capacity));
	}
	
	user_command disaster {
		create disaster with:[location::#user_location];
	}
	
}


species building {
	aspect default{
		draw shape color:#grey;
	}
}

species road {
	int nbLanes;
	int nb_cars <- 0;
	float capacity;
	aspect default{
		draw shape width: nbLanes * 2#m color:rgb(255*nb_cars/capacity,0,0);
	}
}

species corridor {
	aspect default{
		draw shape color:#blueviolet;
	}
}

species people skills:[moving]{
	
	building home_place;
	car my_car;
	
	agent final_destination;
	
	bool at_home update: location overlaps home_place;
	bool is_driving;
	
	init{
		speed <- rnd(5, 10)/10 * pedestrian_speed;
		home_place <- one_of(building);
		location <- any_location_in(home_place);	
	}
	
	aspect base {
		draw circle(2) color:#red;
	}
	
	/*
	 * Choose to go somewhere
	 */
	reflex lets_move when: final_destination = nil and flip(0.1) {
		if(not at_home){
			final_destination <- home_place;
		} else {
			final_destination <- one_of(building where (each != home_place
				and not (location overlaps each)));
		}	
	}
	
	reflex choose_mode when: final_destination != nil 
		and my_car!= nil and my_car.driver = nil
		and my_car distance_to location < walking_distance{
		if(location distance_to my_car < 1#m){
			my_car.driver <- self;
		} else {
			if(not is_driving) {is_driving <- true;}
			do goto target:my_car on: road_network;//pedestrian_network;
		}
	}
	
	/*
	 * If path choosen, the here we go 
	 */
	reflex go_to_destination when: final_destination != nil and not is_driving {
		
		if(location overlaps final_destination){ 
			location <- any_location_in(final_destination);
			final_destination <- nil;
		} else {
			do goto on:road_network/*pedestrian_network*/ target:final_destination;
		}
		
	}
	
	reflex look_at_danger when: not(empty(disaster)) {
		if(!empty(disaster at_distance 20#m)) {
			evacuation evac_point <- evacuation with_min_of (each distance_to location);
			final_destination <- evac_point;			
		}
	}
	
	reflex dead when: length(disaster where (location overlaps each)) > 0{
		if(my_car != nil){
			my_car.driver <- nil;
		}
		casualties <- casualties + 1;
		do die;
	}
	
	reflex evactuate when: final_destination is evacuation {
		if(location distance_to final_destination < 5#m){
			if(my_car != nil and is_driving){
				ask my_car {do die;}
			}
			evacuates <- evacuates + 1;
			do die;
		}
	}
	
}

species car skills:[moving]{
	
	people driver;
	
	init{
		speed <- car_speed;
	}
	
	aspect base{
		draw triangle(5) rotate: 90 + heading color:#blue;
	}
	
	reflex go_to_destination when:driver != nil {
		
		road the_previous_road <- road(current_edge);
		if(current_edge != nil){
			the_previous_road.nb_cars <- the_previous_road.nb_cars - 1; 
		}
		
		if(location overlaps driver.final_destination){
			//location <- self.location - {2.0,2.0};
			
			driver.is_driving <- false;
			driver <- nil;
		} else {
			do goto on:road_network target:driver.final_destination move_weights:road_weights;
			driver.location <- location;
			road the_current_road <- road(current_edge);
			if(the_current_road != nil){
				the_current_road.nb_cars <- the_current_road.nb_cars + 1;
			}
		}
	}
	
}

species disaster {
	
	init{
		shape <- circle(disaster_size);
	}
	
	reflex expand {
		shape <- shape + 1#m;
	}
	
	aspect default {
		draw shape color:#red;
	}
}

species evacuation {
	aspect default{
		draw circle(10) color:#green;
	}
}

experiment traffic_multi_modal type: gui {
	
	parameter "number of people: " var:nb_people;
	parameter "number of car: " var:nb_car;
	
	output {
		display city_gui type: opengl synchronized: true{

			species building aspect:default;
			species road aspect:default;
			species car aspect:base;
			species people aspect:base;
			species disaster aspect:default transparency:0.6;
			species evacuation aspect:default transparency:0.4;
		}
		monitor number_of_casualties value:casualties;
		monitor number_of_evacuates value:evacuates;
	}
}