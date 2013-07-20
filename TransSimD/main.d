module main;

import std.stdio;
import std.file : readText;
import std.string;
import std.csv;
import std.typecons;
import std.array;
import std.conv;
import std.functional;

void main(string[] args)
{
	SimData data = SimData();
	auto parsers = [&parseDrivers, &parseTravelers, &parseRoutes];
	foreach(p;parsers) p(data);

	data.setup();

	stdin.readln();
}

// Parses drivers
void parseDrivers(ref SimData simdata) {
	auto drivers = csvReader!Driver("data/drivers.csv".readText(),',');
	foreach(d; drivers) {
		simdata.drivers[d.startID] ~= d;
	}
}

// Parses travelers
void parseTravelers(ref SimData simdata) {
	auto travelers = csvReader!Traveler("data/passengers.csv".readText(),',');
	foreach(t; travelers) simdata.travelers ~= t;
}

// Parses Routes
void parseRoutes(ref SimData simdata) {
	auto files = ["47VanNess.csv","8xBayshore.csv", "49Mission.csv",
		"KIngleside.csv", "LTaraval.csv", "NJudah.csv","TThird.csv"];

	foreach(file; files) {
		Route route = Route();

		auto f = File("data\\" ~ file);
		route.name = f.readln(','); route.name.popBack();
		f.readln();
		foreach( r; f.byRecord!(string, int)("%s,%s") ) {
			auto s = Station();
			s.id = r[1];
			s.name = r[0];
			simdata.stations[s.id] = s;
			route.stations ~= s;
		}
		//writeln(route.name);
		simdata.routes ~= route;
	}
}

struct SimData {
	Routes routes = [];
	Driver[][int] drivers; // key by starting station ID
	Station[int] stations;
	Traveler[] travelers;

	void setup() {
		// add vehicles and drives to routes
		foreach(r; routes) {
			auto v = Vehicle();
			v.driver = drivers[r.origin().id].front;
			drivers[r.origin().id].popFront();
			r.origin().vehicles ~= v;
			writeln(v.driver.name, " entering vehicle at origin station: ", r.origin().id);

			v = Vehicle();
			v.driver = drivers[r.terminus().id].front;
			drivers[r.terminus().id].popFront();
			r.terminus().vehicles ~= v;

			writeln(v.driver.name, " entering vehicle at terminus station: ", r.origin().id);
		}

		foreach(p; travelers) {
			stations[p.start].travelers ~= p;
		}
		foreach(k, v; stations) {
			writeln("Stop #", k, " has #", v.travelers.length);
		}
	}
}

struct Vehicle {
	Driver driver;
	Route route;
	People passengers;
}
struct Traveler {
	string name;
	int start, end;
}
alias Routes = Route[];
alias People = Traveler[];
struct Route {
	string name;
	Station[] stations;
	Station origin() { return stations[0]; }
	Station terminus() { return stations[stations.length-1]; }
	bool atEndPoints(int id) {
		return origin().id == id || terminus().id == id;
	}
	alias stations this;
}
struct Station {
	string name;
	int id;
	People travelers;
	Vehicle[] vehicles;
}
struct Driver {
	string name;
	int startID;
	int trips=0;
}