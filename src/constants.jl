const BASE_PATH = "https://infoplease.com"
const LINKS = "/primary-sources/government/presidential-speeches/state-union-addresses"
const LEADER = "state-union-address-"
const DATEFMT = dateformat"U d, yyyy)"

const USER = "postgres"
const DATABASE = "postgres"
const PASSWORD = "1An780923!"
const PORT = "5432"
const HOST = "/var/run/postgresql"

const CONN = LibPQ.Connection("postgres://$USER:$PASSWORD@localhost:$PORT")
