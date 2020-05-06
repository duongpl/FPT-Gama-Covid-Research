/***
* Name: NewModel
* Author: DUONG
* Description: 
* Tags: Tag1, Tag2, TagN
***/
model ModelM12

/* Insert your model definition here */
global {
	int num_of_susceptible <- 500;
	int num_of_infectious <- 1;
	float mask_rate <- 0.8;
	float type_I <- 0.7;
	float infected_rate <- 1.0;
	float infected_rateA <- 0.55;
	list<int> r0;
//	geometry shape<-square(150 #m);
	init {
		create infectious number: num_of_infectious;
		create susceptible number: num_of_susceptible;
		
	}
	reflex end_simulation when:(susceptible count (each.state = 2 or each.state = 4 or each.state = 1) + infectious count (each.state = 2)) = 0 {
    	do pause;
    }
    reflex addd{
    	r0 <- [];
				loop s over: susceptible where(each.state = 2 or each.state = 4){
					add s.number_infected to: r0;
				}
				loop s over: infectious where(each.state = 2 or each.state = 4){
					add s.number_infected to: r0;
				}
    }

}

species susceptible skills: [moving] {
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
	int number_infected <- 0;
	
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
					myself.number_infected <- myself.number_infected + 1;
				}

			} else {
				if (self.state = 0 and A) {
					self.state <- 1;
					self.save_time <- time;
					myself.number_infected <- myself.number_infected + 1;
				}

			}

		}

	}
	reflex test{
		write sample(2);
	}
}

species infectious skills: [moving] {
	float speed <- (2 + rnd(5)) #m;
	int state <- 2;
	float infect_range <- 2 #meter;
	float save_time <- 0.0;
	bool have_mask <- flip(mask_rate);
	bool is_infected <- flip(infected_rate);
	int keeptime <- rnd(100, 300);
	int number_infected <- 0;
	reflex moving {
		if ((time - save_time) mod keeptime = 0 and time != 0 and (state = 2 or state = 4)) {
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


	reflex attack when: !empty(susceptible at_distance infect_range) and state = 2 {
		ask susceptible at_distance infect_range {
			if (have_mask) {
				is_infected <- flip(infected_rate * 0.5);
				if (self.state = 0 and is_infected) {
					self.state <- 1;
					self.save_time <- time;
					myself.number_infected <- myself.number_infected + 1;
				}

			} else {
				if (self.state = 0 and is_infected) {
					self.state <- 1;
					self.save_time <- time;
					myself.number_infected <- myself.number_infected + 1;
				}

			}

		}

	}
	
	reflex test{
		write sample(1);
	}
}

experiment myExp type: gui {
	parameter "Infected rate" var: infected_rate;
	parameter "Susceptible have mask rate" var: mask_rate;
	parameter "Number of Infectious" var: num_of_infectious min: 1 max:500;
	parameter "Number of Susceptible" var: num_of_susceptible min: 1 max: 500;
	parameter "Infect rate of I(n)" var: infected_rate;
	parameter "Infect rate of I(a)" var: infected_rateA;

	output {
//		display myDisplay {
//			species susceptible aspect: base;
//			species infectious aspect: base;
//		}
		
		//evolution of the number of I (1.2)
		display chart {
			chart "c" type: series {
				data value: min(r0) legend: "Min" color:#red;
				data value: max(r0) legend: "Max" color:#blue;
				data value: sum(r0)/((susceptible count (each.state = 2 or each.state = 4) + infectious count (each.state = 2)) = 0 ? 1 : (susceptible count (each.state = 2 or each.state = 4) + infectious count (each.state = 2))) legend: "Avarage" color:#orange;
			}
		}
	}

}