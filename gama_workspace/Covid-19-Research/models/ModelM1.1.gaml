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
	float mask_rate <- 0.8;
	float type_I <- 0.7;
	float infected_rate <- 1.0;
	float infected_rateA <- 0.55;


	init {
		create susceptible number: num_of_susceptible;
		create infectious number: num_of_infectious;
	}

}

species susceptible skills: [moving] {
	
	int state <- 0;
	float infect_range <- 2 #meter;
	float save_time <- 0.0;
	int count_I <- num_of_infectious;
	int count_S <- num_of_susceptible;
	bool is_infected <- flip(infected_rate);
	bool is_infectedA <- flip(infected_rateA);
	bool have_mask <- flip(mask_rate);
	bool In_or_Ia <- flip(type_I);
	bool N ;
	bool A ;

	reflex moving {
		if (((time - save_time) mod 100 = 0) and state = 1 and In_or_Ia) {
			state <- 2;
		}else if(((time - save_time) mod 100 = 0) and state = 1 and !In_or_Ia){
			state <- 4;
		}
		else if ((time - save_time) mod 400 = 0 and (state = 2 or state = 4)) {
			state <- 3;
		} 

//		write sample(time);
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
			
			match 4 {
				draw circle(1) color: #red;
			}
		}

	}

	reflex attack when: !empty(susceptible at_distance infect_range) and (state = 2 or state = 4){
		ask susceptible at_distance infect_range {
			if (self.have_mask) {
				N <- flip(infected_rate * 0.5);
				A <- flip(infected_rateA * 0.5);
			}
			if(state = 2){
				if (self.state = 0 and N) {
					self.state <- 1;
					self.save_time <- time;
				}
			}else{
				if (self.state = 0 and A) {
					self.state <- 1;
					self.save_time <- time;
				}
			}
		}
	}
}

species infectious skills: [moving] {
//	float speed <- 1.0;
	int state <- 2;
	float infect_range <- 2 #meter;
	float save_time <- 0.0;
	bool have_mask <- flip(mask_rate);
	bool is_infected <- flip(infected_rate);
	
	reflex moving {
		if ((time - save_time) mod 400 = 0 and time != 0 and (state = 2 or state = 4)) {
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
		write sample(length(infectious));
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

experiment myExp type: gui {
	parameter "Infected rate" var: infected_rate;
	parameter "Susceptible have mask rate" var: mask_rate;
	parameter "Number of Infectious" var: num_of_infectious;
	parameter "Number of Susceptible" var: num_of_susceptible;
	output {
		display myDisplay {
			species susceptible aspect: base;
			species infectious aspect: base;
			overlay transparency: 0.3 background: rgb(99, 85, 66, 255) position: {50 °px, 50 °px} size: {250 °px, 250 °px} border: rgb(99, 85, 66, 255) rounded: true {
				draw ('Number of S: ' + susceptible count (each.state = 0)) at: {40 °px, 70 °px} font: font("Arial", 18, #bold) color:#white;
				draw ('Number of E: ' + susceptible count (each.state = 1)) at: {40 °px, 100 °px} font:font("Arial", 18, #bold) color: #white;
				draw ('Number of I: ' + (susceptible count (each.state = 2 or each.state = 4) + length(infectious))) at: {40 °px, 130 °px} font:font("Arial", 18, #bold) color: #white;
				draw ('Number of R: ' + susceptible count (each.state = 3)) at: {40 °px, 160 °px} font:font("Arial", 18, #bold) color: #white;
			}
		}

	}

}