/***
* Name: NewModel
* Author: DELL
* Description: 
* Tags: Tag1, Tag2, TagN
***/
model session1

/* Insert your model definition here */
global {
	int num_of_susceptible <- 500;
	int num_of_infectious <- 1;
	int num_of_exposed <- 0;

	init {
		create susceptible number: num_of_susceptible;
		create infectious number: num_of_infectious;
		//		create exposed number: num_of_exposed;
	}

}

species susceptible skills: [moving] {
	int state <- 0;
	int attack_range <- 2;
	float save_time <- 0.0;

	reflex moving {
		if ((time - save_time) mod 100 = 0 and state = 1) {
			state <- 2;
		} else if ((time - save_time) mod 100 = 0 and state = 2) {
			state <- 3;
		}

		write sample(time);
		do wander;
	}

	aspect base {
		switch state {
			match 0 {
				draw circle(1) color: #black;
			}

			match 1 {
				draw circle(1) color: #yellow;
			}

			match 2 {
				draw circle(1) color: #red;
			}

			match 3 {
				draw circle(1) color: #green;
			}

		}

	}

	//	reflex infected when: state = 2 {
	//		list<agent> neighbors <- agents at_distance (attack_range);
	//		loop i from: 0 to: length(neighbors) - 1 {
	//			ask neighbors at i {
	//				if (myself.state = 0) {
	//					myself.state <- 1;
	//				}else {
	//					break;
	//				}
	//
	//			}
	//
	//		}
	//
	//	}
	reflex attack when: !empty(susceptible at_distance attack_range) {
		ask susceptible at_distance attack_range {
			if (myself.state = 2 and self.state = 0) {
				self.state <- 1;
				self.save_time <- time;
			}

		}

	}

}

species infectious skills: [moving] {
	int state <- 2;
	int attack_range <- 2;
	float save_time <- 0.0;

	reflex moving {
		if ((time - save_time) mod 100 = 0 and time != 0 and state = 2) {
		//			write sample(time);
			state <- 3;
		}

		do wander;
		//		write sample(time);
	}

	aspect base {
		switch state {
			match 2 {
				draw circle(1) color: #red;
			}

			match 3 {
				draw circle(1) color: #green;
			}

		}

	}

	reflex attack when: !empty(susceptible at_distance attack_range) {
		ask susceptible at_distance attack_range {
			if (myself.state = 2 and self.state = 0) {
				self.state <- 1;
				self.save_time <- time;
			}

		}

	}

}

//species rat skills: [moving] {
//	bool is_infected <- flip(0.5);
//	int attack_range <- 5;
//
//	reflex moving {
//		do wander;
//	}
//
//	//	reflex attack when: !empty(people at_distance attack_range ) {
//	//		ask people at_distance attack_range {
//	//			if(self.is_infected) {
//	//				myself.is_infected <- true;
//	//			}else if(myself.is_infected) {
//	//				self.is_infected <- true;
//	//			}
//	//		}
//	//	}
//	aspect base {
//		draw circle(1) color: (is_infected) ? #red : #green;
//	}
//
//}
experiment myExp type: gui {
//	parameter "number of susceptible" var: num_of_susceptible;
//	//	parameter "number of rat" var: num_of_rat;
	output {
		display myDisplay {
			species susceptible aspect: base;
			species infectious aspect: base;
		}

		//		display my_chart {
		//			chart "number of infected" {
		//			//				data "infected people" value: length (people where (each.is_infected = true));
		//			}
		//
		//		}

	}

}