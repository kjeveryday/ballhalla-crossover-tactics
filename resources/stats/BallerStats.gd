class_name BallerStats extends Resource
# BallerStats — exported resource for all baller stat data.
# Create .tres instances in resources/stats/allied/ and resources/stats/enemy/.

enum BallerPosition { PG = 0, SG = 1, SF = 2, PF = 3, C = 4 }

@export var display_name: String = ""
@export var position: int = 0          # BallerPosition enum value

@export_group("Shooting")
@export var shooting_2pt: float = 0.45
@export var shooting_3pt: float = 0.33

@export_group("Core Stats")
@export var speed: int = 4
@export var handle: int = 5
@export var pass_rating: int = 5
@export var offensive_rating: int = 50
@export var defensive_rating: int = 50
@export var rebound_rating: int = 5
@export var block_rating: int = 5

@export_group("Resources")
@export var max_stamina: int = 150
@export var gravity_base: int = 4
@export var hype_charge_rate: float = 0.25
@export var turnover_chance: float = 0.02
