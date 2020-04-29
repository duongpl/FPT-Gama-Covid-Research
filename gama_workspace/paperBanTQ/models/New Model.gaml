/***
* Name: NewModel
* Author: DELL
* Description: 
* Tags: Tag1, Tag2, TagN
***/

model NewModel

/* Insert your model definition here */

global {
	int num_of_people <- 50;
	int num_of_rat <- 20;
	
	init {
		create people number:num_of_people;
		create rat number:num_of_rat;
	}
}
species people skills:[moving]{
	bool is_infected <- false;
	
	reflex moving {
		do wander;
	}
	
	aspect base {
		draw circle(2) color: (is_infected)? #red : #green;
	}
}
species rat skills:[moving]{
	bool is_infected <- flip(0.5);
	int attack_range <- 5;
	reflex moving {
		do wander;
	}
	
	reflex attack when: !empty(people at_distance attack_range ) {
		ask people at_distance attack_range {
			if(self.is_infected) {
				myself.is_infected <- true;
			}else if(myself.is_infected) {
				self.is_infected <- true;
			}
		}
	}
		aspect base {
		draw circle(1) color: (is_infected)? #red : #green;
	}
}
experiment myExp type:gui {
	parameter "number of people" var: num_of_people;
	parameter "number of rat" var: num_of_rat;
	output {
		display myDisplay {
			species people aspect:base;
			species rat aspect:base;
		}
		display my_chart{
			chart "number of infected" {
				data "infected people" value: length (people where (each.is_infected = true));
			}
		}
	}
}