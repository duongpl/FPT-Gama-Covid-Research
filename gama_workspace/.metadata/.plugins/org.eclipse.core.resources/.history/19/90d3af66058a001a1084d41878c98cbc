/***
* Name: NewModel
* Author: DELL
* Description: 
* Tags: Tag1, Tag2, TagN
***/
model session1

/* Insert your model definition here */
global {
	int num_of_susceptible <- 100;
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

	reflex moving {
		if (cycle mod 1000 = 0 and state = 1) {
			state <- 2;
		} else if (cycle mod 1000 = 0 and state = 2) {
			state <- 3;
		}

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
			}

		}

	}

}

species infectious skills: [moving] {
	int state <- 2;
	int attack_range <- 2;

	reflex moving {
		if (cycle mod 1000 = 0 and cycle != 0 and state = 2) {
			write sample(cycle);
			state <- 3;
		}

		do wander;
		//		write sample(cycle);
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