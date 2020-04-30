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
	float mask_rate <- 0.5;
	float E_to_I_rate <- 0.4;
	bool have_mask <- flip(mask_rate);
	float infected_rate <- 0.19;
	bool is_infected <- flip(infected_rate);

	init {
		create susceptible number: num_of_susceptible;
		create infectious number: num_of_infectious;
	}

}

species susceptible skills: [moving] {
	int state <- 0;
	float attack_range <- 2 #meter;
	float save_time <- 0.0;
	int count_I <- num_of_infectious;
	int count_S <- num_of_susceptible;
	bool to_I_or_S <- flip(E_to_I_rate);

	reflex moving {
		if (((time - save_time) mod 100 = 0) and (state = 1) and to_I_or_S) {
			state <- 2;
		} else if ((time - save_time) mod 100 = 0 and state = 2) {
			state <- 3;
		} else {
			state <- 0;
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

	reflex attack when: !empty(susceptible at_distance attack_range) {
		ask susceptible at_distance attack_range {
			if (have_mask) {
				is_infected <- flip(infected_rate * 0.5);
				if (myself.state = 2 and self.state = 0 and is_infected) {
					self.state <- 1;
					self.save_time <- time;
				}

			} else {
				if (myself.state = 2 and self.state = 0 and is_infected) {
					self.state <- 1;
					self.save_time <- time;
				}

			}

		}

	}

}

species infectious skills: [moving] {
	int state <- 2;
	float attack_range <- 2 #meter;
	float save_time <- 0.0;
	bool to_I_or_S <- flip(E_to_I_rate);

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
			if (have_mask) {
				is_infected <- flip(infected_rate * 0.5);
				if (myself.state = 2 and self.state = 0 and is_infected) {
					self.state <- 1;
					self.save_time <- time;
				}

			} else {
				if (myself.state = 2 and self.state = 0 and is_infected) {
					self.state <- 1;
					self.save_time <- time;
				}

			}

		}

	}

}

experiment myExp type: gui {
	parameter "Infected rate" var: infected_rate;
	parameter "Susceptible have mask rate" var: mask_rate;
	parameter "Number of Infectious" var: num_of_infectious;
	parameter "Number of Susceptible" var: num_of_susceptible;
	parameter "E to I rate" var: E_to_I_rate;
	output {
		display myDisplay {
			species susceptible aspect: base;
			species infectious aspect: base;
		}

	}

}