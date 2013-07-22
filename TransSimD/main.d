module main;

import std.stdio;
import std.file : readText;
import std.string;
import std.csv;
import std.typecons;
import std.array;
import std.conv;
import std.functional;

enum SIM_STEPS = 30;

void main(string[] args)
{
	writeln("sim started");
	SimData data = SimData();
	auto parsers = [&parseDrivers, &parseTravelers, &parseRoutes];
	foreach(ref p;parsers) p(data);
	writeln("parsed");
	data.setup();
	writeln("setup finished");

	for(int i=0; i < SIM_STEPS; i++) data.step();

	stdin.readln();
}

// Parses drivers
void parseDrivers(ref SimData simdata) {
	auto drivers = csvReader!Driver("data/drivers.csv".readText(),',');
	foreach(ref d; drivers) {
		simdata.drivers[d.startID] ~= d;
	}
}

// Parses travelers
void parseTravelers(ref SimData simdata) {
	auto f = File("data/passengers.csv");
	foreach(ref r; f.byRecord!(string, int, int)("%s,%s,%s") ) {
		Traveler* t = new Traveler();
		t.name = r[0]; t.start = r[1]; t.end = r[2];
		simdata.travelers[t.key()] = t;
	}
}

// Parses Routes
void parseRoutes(ref SimData simdata) {
	auto files = ["47VanNess.csv","8xBayshore.csv", "49Mission.csv",
		"KIngleside.csv", "LTaraval.csv", "NJudah.csv","TThird.csv"];

	foreach(ref file; files) {
		Route *route = new Route();

		auto f = File("data\\" ~ file);
		route.name = f.readln(','); route.name.popBack();
		f.readln();
		foreach(ref r; f.byRecord!(string, int)("%s,%s") ) {
			auto s = new Station();
			s.id = r[1];
			s.name = r[0];
			simdata.stations[s.id] = s;
			route.stations ~= s;
		}
		simdata.routes ~= route;
	}
}

struct SimData {
	Routes routes = [];
	Driver[][int] drivers; // key by starting station ID
	Station*[int] stations;
	Traveler*[string] travelers;
	Vehicle*[] vehicles=[];
	// Set the vehicles at their stations as well as the travelers
	void setup() {
		// add vehicles and drives to routes
		foreach(ref r; routes) {
			auto v = makeVehicle(*r.origin(), *r);
			writeln(v.driver.name, " entering vehicle at origin station: ", r.origin().id, " = ", v.currentStation().id);

			v = makeVehicle(*r.terminus(), *r);
			v.reverse();
			writeln(v.driver.name, " entering vehicle at terminus station: ", r.terminus().id, " = ", v.currentStation().id);
		}

		foreach(key, ref p; travelers) {
			//writeln(p.start, " ", stations.length );

			//if( p.start !in stations ) stations[p.start] = [];
			stations[p.start].travelers[p.key()] = p;
		}
		/*
		foreach(k, v; stations) {
			writeln("Stop #", k, " has #", v.travelers.length);
		}
		*/
	}
	ref Vehicle makeVehicle(ref Station station, ref Route r) {
		if(drivers[station.id].length==0) {
			//TODO
		}
		auto v = new Vehicle(r);
		v.driver = drivers[station.id].front;
		drivers[station.id].popFront();
		vehicles ~= v;
		return *v;
	}

	void step() {
		//
		writeln("step started");
		foreach(ref v; vehicles) {
			updateVehicle(*v);
			updateStation(*v, *v.currentStation());
			v.travel(); // arriving on station
			//writeln("Driver traveled:", v.driver.name, " ", v.last.id,"->",v.currentStation().id);
		}

		writeln("step ended");
	}
	void updateVehicle(ref Vehicle v) {
		foreach(key, ref t; v.passengers) {
			if(t.end==v.currentStation().id) {
				travelerExits(*t, v);
			}
		}
	}
	void updateStation(ref Vehicle v, ref Station s) {
		//writeln(s.travelers.length);
		Traveler*[] boardedTravelers;
		foreach(ref t; s.travelers) {
			if( v.isFull() ) continue;
			if( v.onTheWay( t.end ) ) {
				v.board(*t);
				boardedTravelers ~= t;
			}
		}
		foreach(ref t; boardedTravelers) s.travelers.remove(t.key());
	}
	void travelerExits(ref Traveler t, ref Vehicle v) {
		//v.travelers.remove(v);
		v.passengers.remove(t.key());
		writeln("Traveler ",t.name, " exits vehicle: ", v.driver.name, " from route: ", v.route.name);
	}
	void updatePerson(ref Traveler p, ref Station s) {

	}
}

struct Vehicle {
	Driver driver;
	Route route;
	Station*[] traveling; // list of stations in its current direction
	People passengers;
	bool goingToOrigin;
	int capacity = 50;
	Station* last;

	this(ref Route route) {
		this.route = route;
		traveling.length = route.stations.length;
		traveling[] = route.stations[];
	}

	void board(ref Traveler t) {
		if(isFull()) return;
		passengers[t.key()] = &t;
		///writeln(t.name, " is boarding on ", driver.name, "'s buss"); 
	}

	bool isFull() {
		return passengers.length >= 50;
	}

	bool onTheWay(int id) {
		bool r=false;
		foreach(ref t;traveling) if(t.id==id) return true;
		return false;
	}

	void reverse() {
		goingToOrigin = !goingToOrigin;
		if(goingToOrigin) traveling = traveling.reverse;
	}

	ref auto currentStation() { return traveling[0]; }

	ref auto travel() {
		last = currentStation();
		traveling = traveling[1..$];
		if(traveling.length==0) {
			traveling.length = route.stations.length;
			traveling[] = route.stations[];
			reverse();
		}

		return currentStation();
	}
}
struct Traveler {
	string name;
	int start, end;

	private string _key=null;
	ref string key() {
		if(_key==null) _key = name ~ std.conv.to!string(start) ~ ":" ~ std.conv.to!string(end);
		return _key;
	}
}
alias Routes = Route*[];
alias People = Traveler*[string];
struct Route {
	string name;
	Station*[] stations;
	ref auto origin() { return stations[0]; }
	ref auto terminus() { return stations[stations.length-1]; }
	bool atEndPoints(int id) {
		return origin().id == id || terminus().id == id;
	}
	bool has(int id) {
		bool r;
		foreach(ref s;stations) if(s.id==id) return true;
		return false;
	}
	alias stations this;
}
struct Station {
	string name;
	int id;
	People travelers;
	//Vehicle[] vehicles;
}
struct Driver {
	string name;
	int startID;
	int trips=0;
}