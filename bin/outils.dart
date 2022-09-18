// ignore_for_file: prefer_interpolation_to_compose_strings, constant_identifier_names, file_names, unnecessary_brace_in_string_interps, unnecessary_this
import "dart:convert";
import 'dart:math';
import "dart:typed_data";
import "dart:io";
import "package:path/path.dart" as path;


class ImageRom{
  int adresse = 0;
  List<int> pointeurs = [];
  ImageRom({required this.adresse});

  Map toJson() => {
    'adresse' : adresse,
    'pointeurs': pointeurs,
  };
  ImageRom.fromJson(Map<String, dynamic> json)
      : adresse = json["adresse"],
        pointeurs = List<int>.from(json["pointeurs"]);
}

class Size{
  int width;
  int height;
  Size(this.width, this.height);
  @override
  String toString() {
    return "${width}Lx${height}H";
  }
  List<int> toJson() =>  [width, height];
  Size.fromJson(List<dynamic> size)
      : width = size[0],
      height = size[1];
}

class MapSize{
  int dim;
  List<Size> sizes;
  List<ImageRom> imagesRom = [];
  List<int> enteteRom = [];
  List<int> enteteJcalg1 = [];
  String typeTuile;
  MapSize(this.typeTuile, this.dim, this.sizes){
    enteteRom = [0x01, 0x00, 0x00, 0x00] +  dim.toOctets(4, Endian.little);
    enteteJcalg1 = [0x4A, 0x43] +   dim.toOctets(4, Endian.little) + [0x00, 0x00, 0x00, 0x00];
  }

  @override
  String toString() {
    String texte = "";
    texte += "---------------------------------------------\n";
    texte += "- TypeTuile : $typeTuile\n";
    texte += "- Dimension : $dim\n";
    texte += "- Sizes : $sizes\n";
    texte += "- En-tête Rom : ${toHexList(enteteRom)}\n";
    texte += "- En-tête Jcalg1 : ${toHexList(enteteJcalg1)}\n";
    texte += "- Images Rom :\n";
    for(ImageRom img in imagesRom){
      texte += "Adresse : ${img.adresse.toRadixString(16)} => Pointeurs : ${toHexList(img.pointeurs)}\n";
    }
    texte += "---------------------------------------------\n";
    return texte;
  }

  Map toJson() => {
    'typeTuile' : typeTuile,
    'dim': dim,
    'enteteRom' : enteteRom,
    'enteteJcalg1' : enteteJcalg1,
    'sizes': sizes,
    'imagesRom' : imagesRom
  };

  MapSize.fromJson(Map<String, dynamic> json)
      : typeTuile = json['typeTuile'],
        dim = json['dim'],
        enteteRom = List<int>.from(json['enteteRom']),
        enteteJcalg1 = List<int>.from(json['enteteJcalg1']),
        sizes = List<Size>.from(json["sizes"].map((size)=> Size.fromJson(size))),
        imagesRom = List<ImageRom>.from(json["imagesRom"].map((img)=> ImageRom.fromJson(img)));

  String creerNomFichierComp(int indice){
    int pad = (imagesRom.length-1).toString().length;
    return "comp-" + typeTuile + "-" + "dim_" + dim.toString() + "-i_" + indice.toString().padLeft(pad,"0") +  "-adr_" + imagesRom[indice].adresse.toRadixString(16).padLeft(6, "0") + ".txt";
  }

  String creerNomFichierDecomp(int indice){
    int pad = (imagesRom.length-1).toString().length;
    return "decomp-" + typeTuile + "-" + "dim_" + dim.toString() + "-i_" + indice.toString().padLeft(pad,"0") +  "-adr_" + imagesRom[indice].adresse.toRadixString(16).padLeft(6, "0") + ".txt";
  }

  String creerNomFichieBitmap(int indice, int width, int height){
    int pad = (imagesRom.length-1).toString().length;
    return typeTuile + "-" + "dim_" + dim.toString() + "(${width}x${height})" +"-i_" + indice.toString().padLeft(pad,"0") +  "-adr_" + imagesRom[indice].adresse.toRadixString(16).padLeft(6, "0") + ".bmp";
  }
}



class Global{
  static final nomRom = "buus_fury.gba";
  static const String nomDossierSources  = "Sources";
    static final String cheminRom = path.join(nomDossierSources, nomRom);
    static final String cheminJcalg1 = path.join(nomDossierSources, "jcalg1.exe");
    static final String cheminPalSprite = path.join(nomDossierSources, "mgba_pal_sprite.pal");
    static final String cheminPalBackground = path.join(nomDossierSources, "mgba_pal_Background.pal");

  static const String nomDossierInfos  = "Infos";
    static final String cheminInfos = path.join(nomDossierInfos, "infos.json");
  static const String nomDossierDecomp = "Decomp";
  static const String nomDossierImages = "Images";


  /* Paramètres immuables */
  static const  List<int> modele_entete_jcalg1 = [0x4A, 0x43, 0x00, 0x04, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00];
  static const  List<int> modele_entete_rom    = [0x01, 0x00, 0x00, 0x00, 0x00, 0x04, 0x00, 0x00];


  static List<int> romOctets = [];
  /*
  Available sprite pixel sizes
  +--------------+-------+--------+-------+-------+
  | shape / size | small | normal |  big  | huge  |
  +--------------+-------+--------+-------+-------+
  | square       | 8x8   | 16x16  | 32x32 | 64x64 |
  | wide         | 16x8  | 32x8   | 32x16 | 64x32 |
  | tall         | 8x16  | 8x32   | 16x32 | 32x64 |
  +--------------+-------+--------+-------+-------+
  */
  /*
  Available background pixel sizes
  +-------------+---------+---------+---------+-----------+
  | shape /size |  small  | normal  |   big   |   huge    |
  +-------------+---------+---------+---------+-----------+
  | square      | 128x128 | 256x256 | 512x512 | 1024x1024 |
  | wide        |         |         | 512x256 |           |
  | tall        |         |         | 256x512 |           |
  +-------------+---------+---------+---------+-----------+
  */

  static List<MapSize> listeMap = [
    // Sprites
    MapSize("sprite", 64,   [Size(8,8)]),
    MapSize("sprite", 128,  [Size(16,8),  Size(8,16)]),
    MapSize("sprite", 256,  [Size(16,16), Size(32,8), Size(8,32)]),
    MapSize("sprite", 512,  [Size(32,16), Size(16,32)]),
    MapSize("sprite", 1024, [Size(32,32)]),
    MapSize("sprite", 2048, [Size(64,32), Size(32,64)]),
    MapSize("sprite", 4096, [Size(64,64)]),

    // Backgrounds
    MapSize("background", 15424,   [Size(128,128)]), // car je le sais
    MapSize("background", 16384,   [Size(128,128)]),
    MapSize("background", 65536,   [Size(256,256)]),
    MapSize("background", 131072,  [Size(256,512), Size(512,256)]),
    MapSize("background", 262144,  [Size(512,512)]),
    MapSize("background", 1048576, [Size(1024,1024)]),
  ];
}

extension MonInt on int{
  List<int> toOctets(int pad, Endian endian){
    pad = max((this.bitLength/8).ceil(), pad);
    List<int> listeOctets = [];
    for(int i =0 ; i < pad ; i++){
      listeOctets.add((this >> (i*8)) & 0xff);
    }
    if(endian == Endian.big){
      return listeOctets.reversed.toList();
    }
    else {
      return listeOctets;
    }
  }
}

// Big endian
int octetsToInt(List<int> octets) {
  int res = 0;
  List<int> reverse = octets.reversed.toList();
  for(int i = 0; i < reverse.length ; i++){
    res = res | reverse[i] << i * 8;
  }
  return res;
}

List<String> toHexList(List<int> entree, {int nbPad = 2}) => entree.map((e) => e.toRadixString(16).padLeft(nbPad,'0').toUpperCase()).toList();

bool egaliteListes(List<List<int>> listes){
  // Verifier longueurs
  bool egaliteLongueurs = listes.map((liste) => liste.length).toSet().length == 1;
  if(!egaliteLongueurs && listes.isEmpty){
    print("Longueur Différente");
    return false;
  }
  // Verifier valeurs
  for(int i = 0; i < listes.first.length; i++){
    List<int> vals = [];
    for (List<int> liste in listes) {
      vals.add(liste[i]);
    }
    if(vals.toSet().length > 1){
      print(i);
      return false;
    }
  }
  return true;
}

bool egaliteDeuxListes(List<int> liste_1, List<int> liste_2) {
  if(liste_1.length!=liste_2.length) {
    return false;
  }
  for(int i=0 ; i < liste_1.length ; i++) {
    if(liste_1[i] != liste_2[i]) {
      return false;
    }
  }
  return true;
}


void decompresserJcalg1(String cheminEntree, String cheminSortie){
  //print("Décompression JCALG1");
  ProcessResult result = Process.runSync(path.join(Global.cheminJcalg1) , ['d', cheminEntree, cheminSortie],  runInShell: false, stdoutEncoding:Utf8Codec(), stderrEncoding: Utf8Codec());
  //stdout.write(result.stdout);
  //stderr.write(result.stderr);
  //print("");
}