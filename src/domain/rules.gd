extends RefCounted
## Réglages de la simulation qui ne dépendent pas d'un bâtiment (ceux-là sont dans les données).

const TICKS_PER_MONTH := 200
const WALKER_STEP_TICKS := 4

# Services et marcheurs
const SERVICE_TICKS := 1000
const SERVICE_RADIUS := 2
const SERVICE_COOLDOWN := 10

# Habitat
const HOUSE_ROAD_RADIUS := 2
const HOUSE_FOOD_MONTHS := 4
const HOUSE_GOODS_STOCK := 2
const HOUSE_DOWNGRADE_MONTHS := 2
const PEOPLE_PER_FOOD := 5.0
const IMMIGRATION_PERIOD := 12
const IMMIGRANT_GROUP := 4

# Logistique
const CART_LOAD := 10
const PRODUCER_MAX_STOCK := 30
const LOGISTICS_PERIOD := 10

# Main-d'œuvre
const WORKER_RATIO := 0.5
const LABOR_PERIOD := 20
const WORK_PRIORITY := ["alimentation", "stockage", "services", "religion", "industrie", "monuments"]

# Dieux
const START_FAVOR := 40.0
const FESTIVAL_COST := 150
const FESTIVAL_FAVOR := 12.0
const FESTIVAL_COOLDOWN := 4
const BLESSING_FAVOR := 80.0
const WRATH_FAVOR := 15.0
const UNHAPPY_FAVOR := 25.0

# Risques
const RISK_LIMIT := 100.0
