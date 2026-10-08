class Plant {
  const Plant({
    required this.name,
    required this.species,
    this.location,
    required this.wateringNote,
    required this.description,
    required this.light,
    required this.humidity,
    required this.soil,
    required this.petSafety,
  });

  final String name;
  final String species;
  final String? location;
  final String wateringNote;
  final String description;
  final String light;
  final String humidity;
  final String soil;
  final String petSafety;
}

const List<Plant> savedPlants = [
  Plant(
    name: 'Monstera',
    species: 'Monstera deliciosa',
    location: 'Living room',
    wateringNote: 'Water when the top 2 to 3 cm of soil feels dry.',
    description: 'A tropical climbing plant known for its large, split leaves.',
    light: 'Bright, indirect light. Protect it from harsh afternoon sun.',
    humidity: 'Prefers moderate to high humidity; misting is optional.',
    soil: 'Use a chunky, well-draining mix with bark or perlite.',
    petSafety: 'Toxic to cats and dogs if chewed.',
  ),
  Plant(
    name: 'Sweet Basil',
    species: 'Ocimum basilicum',
    location: 'Kitchen window',
    wateringNote: 'Water when the surface begins to feel dry.',
    description: 'A fragrant culinary herb that grows best in warm conditions.',
    light: 'At least 6 hours of direct sunlight each day.',
    humidity: 'Average indoor humidity is suitable; provide airflow.',
    soil: 'Use rich, moist potting soil in a container with drainage.',
    petSafety: 'Generally considered non-toxic to cats and dogs.',
  ),
  Plant(
    name: 'Snake Plant',
    species: 'Dracaena trifasciata',
    location: 'Bedroom',
    wateringNote: 'Let the soil dry fully; water every 2 to 3 weeks as needed.',
    description: 'A resilient upright plant that tolerates lower-light rooms.',
    light: 'Indirect light is best, though it tolerates low light.',
    humidity: 'Typical household humidity is suitable.',
    soil: 'Use a fast-draining cactus or succulent potting mix.',
    petSafety: 'Toxic to cats and dogs if chewed.',
  ),
];

const List<Plant> plantCatalog = [
  ...savedPlants,
  Plant(
    name: 'Golden Pothos',
    species: 'Epipremnum aureum',
    wateringNote: 'Water when the top half of the soil has dried.',
    description: 'A trailing vine with heart-shaped, variegated leaves.',
    light: 'Bright, indirect light keeps the variegation vivid.',
    humidity: 'Average indoor humidity works well.',
    soil: 'Choose a loose, well-draining indoor potting mix.',
    petSafety: 'Toxic to cats and dogs if chewed.',
  ),
  Plant(
    name: 'Peace Lily',
    species: 'Spathiphyllum wallisii',
    wateringNote: 'Water when the leaves begin to droop slightly.',
    description:
        'A flowering tropical plant with glossy leaves and white blooms.',
    light: 'Medium, indirect light; avoid direct sun.',
    humidity: 'Enjoys higher humidity and warm rooms.',
    soil: 'Use an evenly moist, well-draining potting mix.',
    petSafety: 'Toxic to cats and dogs if chewed.',
  ),
];
