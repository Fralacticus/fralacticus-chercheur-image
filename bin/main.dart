// ignore_for_file: constant_identifier_names
import "dart:convert";
import "dart:io";
import "dart:typed_data";
import "package:collection/collection.dart";
import "package:path/path.dart" as path;
import "package:interact/interact.dart";
import "package:tint/tint.dart";

import "createur_bitmap.dart" as bmp;
import "outils.dart";

void main(){
  afficherTitre();
  print("################ Début du programme ################");
  actionInitialiser();
  bool continuer = true;
  bool rechercheEstMemoire = false;
  while(continuer){
    final choixMenuPrincipal = ["Chercher les adresses et leurs pointeurs", "Décompresser les images", "Créer les bitmap", "Quitter"];

    int selection = Select(
      prompt: "Menu principal" ,
      options: choixMenuPrincipal,
      initialIndex: 0, // optional, will be 0 by default
    ).interact();

    switch(selection){
      case 0 : {
        actionChercherAdressesEtPointeurs();
        rechercheEstMemoire;
      } break;
      case 1 : actionDecompresserImages(rechercheEstMemoire); break;
      case 2 : actionCreerBitmap(rechercheEstMemoire); break;
      case 3 : {
        final doitQuitter = Confirm(
          prompt: "Êtes-vous sûr de vouloir quitter ?",
          defaultValue: false,
          waitForNewLine: true,
        ).interact();
        if(doitQuitter == true) {
          continuer = false;
        }
      }break;
    }
  }
}

void afficherTitre(){
  print("""
 ██████ ██   ██ ███████ ██████   ██████ ██   ██ ███████ ██    ██ ██████      ██ ███    ███  █████   ██████  ███████ 
██      ██   ██ ██      ██   ██ ██      ██   ██ ██      ██    ██ ██   ██     ██ ████  ████ ██   ██ ██       ██      
██      ███████ █████   ██████  ██      ███████ █████   ██    ██ ██████      ██ ██ ████ ██ ███████ ██   ███ █████   
██      ██   ██ ██      ██   ██ ██      ██   ██ ██      ██    ██ ██   ██     ██ ██  ██  ██ ██   ██ ██    ██ ██      
 ██████ ██   ██ ███████ ██   ██  ██████ ██   ██ ███████  ██████  ██   ██     ██ ██      ██ ██   ██  ██████  ███████ 
                                                                                                                    """);
  print("Pour extraire les images du jeu GBA DBZ Buu's Fury");
  print("Créé par Fralacticus (www.fralacticus.fr)\n".bold());
}

void actionInitialiser(){
  print("""
+----------------+
| Initialisation |
+----------------+""");

  if(!File(Global.cheminRom).existsSync()){
    print("ERREUR : La rom de DBZ Buu's Fury est inexistante au chemin '${Global.cheminRom}'".red());
    print("Veuillez placer la rom dans le dossier ${Global.nomDossierSources} avec le nom ${Global.nomRom}");
    print("Appuyez sur la touche Entrée pour quitter");
    stdin.readLineSync();
    exit(-1);
  }
  print("- Rom utilisée : ${Global.cheminRom}");

  print("- Création des dossiers d'export");
  Directory(Global.nomDossierInfos).createSync();
  Directory(Global.nomDossierDecomp).createSync();
  Directory(Global.nomDossierImages).createSync();

  print("- Lecture de la rom du jeu");
  Global.romOctets = File(Global.cheminRom).readAsBytesSync();
  print("");
}

void actionChercherAdressesEtPointeurs(){
  print("- Supression de tous le contenu dans ${Global.nomDossierInfos}");
  Directory(Global.nomDossierInfos).deleteSync(recursive: true);
  Directory(Global.nomDossierInfos).createSync();

  print("- Récupération de chaque adresse d'image");
  listerAdresses(Global.romOctets);

  print("- Recherche des pointeurs de chaque adresse d'image : ");
  chercherMap(Global.romOctets);

  print("- Transformation en Json des informations obtenues");
  Map preJson  = {
    'infos' :  Global.listeMap
  };
  String monJson = jsonEncode(preJson);

  print("- Écriture du fichier ${Global.cheminInfos}");
  File(Global.cheminInfos).writeAsStringSync(monJson);
}

void actionDecompresserImages(bool rechercheEstMemoire){
  if(!rechercheEstMemoire){
    if(!File(Global.cheminInfos).existsSync()){
      print("Attention : Le fichier ${Global.cheminInfos} n'existe pas");
      print("Lancez d'abord 'Chercher les adresses et leurs pointeurs'");
      return;
    }
    print("- Lecture du fichier ${Global.cheminInfos}");
    String infos  = File(Global.cheminInfos).readAsStringSync();
    var json  = jsonDecode(infos);
    Global.listeMap.clear();
    Global.listeMap = List<MapSize>.from(json["infos"].map((e)=> MapSize.fromJson(e)));
  }

  print("- Supression de tous le contenu dans ${Global.nomDossierDecomp}");
  Directory(Global.nomDossierDecomp).deleteSync(recursive: true);
  Directory(Global.nomDossierDecomp).createSync();

  print("- Écriture et décompression des fichiers compressés (non-tronqués) :");
  for(int i = 0; i < Global.listeMap.length; i++){
    MapSize mapSize = Global.listeMap[i];
    String cheminDossier = path.join(Global.nomDossierDecomp, mapSize.dim.toString());
    Directory(cheminDossier).createSync();
    for(int j = 0; j < mapSize.imagesRom.length ; j++){
      ImageRom img = mapSize.imagesRom[j];
      String nomComp = mapSize.creerNomFichierComp(j);
      String nomDecomp = mapSize.creerNomFichierDecomp(j);

      List<int> blocOctets = mapSize.enteteJcalg1 + Global.romOctets.sublist(img.adresse +  mapSize.enteteRom.length );
      stdout.write("\rImages ${mapSize.dim} pixels : ${j+1} / ${mapSize.imagesRom.length}");
      File(path.join(cheminDossier, nomComp)).writeAsBytesSync(blocOctets);
      decompresserJcalg1(path.join(cheminDossier, nomComp), path.join(cheminDossier, nomDecomp));

      // Purge du fichier non compressé brut
      File(path.join(cheminDossier, nomComp)).deleteSync();
    }
    print("");
  }
}

void actionCreerBitmap(bool rechercheEstMemoire){
  if(!rechercheEstMemoire){
    if(!File(Global.cheminInfos).existsSync()){
      print("Attention : Le fichier ${Global.cheminInfos} n'existe pas");
      print("Lancez d'abord 'Chercher les adresses et leurs pointeurs'");
      return;
    }
    print("- Lecture du fichier ${Global.cheminInfos}");
    String infos  = File(Global.cheminInfos).readAsStringSync();
    var json  = jsonDecode(infos);
    Global.listeMap.clear();
    Global.listeMap = List<MapSize>.from(json["infos"].map((e)=> MapSize.fromJson(e)));
  }


  List<FileSystemEntity> listeElement = Directory(Global.nomDossierDecomp).listSync(recursive: true);
  if(listeElement.every((element) => element.statSync().type == FileSystemEntityType.directory )){
    print("Attention : Il n'y a aucun fichier décompressé");
    print("Utilisez d'abord 'Décompresser les images'");
    return;
  }

  print("- Suppression de tous le contenu dans ${Global.nomDossierImages}");
  Directory(Global.nomDossierImages).deleteSync(recursive: true);
  Directory(Global.nomDossierImages).createSync();

  print("- Création et écriture des bitmap : ");
  List<bmp.GenrePix> listeGenrePix = [bmp.GenrePix.sansLignes, bmp.GenrePix.avecChunks];
  for(int i = 0; i < Global.listeMap.length; i++) {
    MapSize mapSize = Global.listeMap[i];
    String cheminDecomp = path.join(Global.nomDossierDecomp, mapSize.dim.toString());
    String cheminImages = path.join(Global.nomDossierImages, mapSize.dim.toString());
    Directory(cheminImages).createSync();
    for(int j = 0; j < mapSize.imagesRom.length ; j++) {
      stdout.write("\rImages ${mapSize.dim} pixels : ${j+1} / ${mapSize.imagesRom.length}");
      String nomDecomp = mapSize.creerNomFichierDecomp(j);
      List<int> octets = File(path.join(cheminDecomp, nomDecomp)).readAsBytesSync();

      loopSize:
      for(int s = 0; s < mapSize.sizes.length; s++){

        for(var legenrePix in listeGenrePix) {
          Size size = mapSize.sizes[s];
          late bmp.Bitmap bitmap;

          try {
            bitmap = bmp.Bitmap(inputPix: octets,
                pal: mapSize.typeTuile,
                Width: size.width,
                Height: size.height,
                genrePix: legenrePix,
                estPhotoshop: false);
          } catch (e) {
            print(e);
            continue loopSize;
          }

          List<int> bmpOctets = bitmap.bmpOctets;

          String nomFichierBitmap = mapSize.creerNomFichieBitmap(
              j, size.width, size.height, legenrePix.name);
          File(path.join(cheminImages, nomFichierBitmap)).writeAsBytesSync(
              bmpOctets);
        }
      }

    }
    print("");
  }
}

void listerAdresses(List<int> romOctets){
  for(int i = 0; i < romOctets.length - Global.modele_entete_rom.length; i+=4){
    loopMap:
    for(MapSize mapSize in Global.listeMap){
      if(egaliteDeuxListes(mapSize.enteteRom, romOctets.sublist(i, i+ Global.modele_entete_rom.length))){
        mapSize.imagesRom.add(ImageRom(adresse: i));
        break loopMap;
      }
    }
  }
}


void chercherMap(List<int> romOctets){
  List<List<int>> blocsOctets = [];
  for(int i = 0; i < romOctets.length ; i+=4){
    blocsOctets.add(romOctets.sublist(i, i+ 4));
  }
  mainloop:
  //for(int i = 20000; i < 150000 ; i++){ // DEBUG
  for(int i = 0; i < blocsOctets.length ; i++){
    stdout.write("\r$i / ${blocsOctets.length}");
    for(MapSize mapSize in Global.listeMap){
      for(ImageRom imgRom in mapSize.imagesRom){
        List<int> octetsPointeur = MonInt(imgRom.adresse + 0x08000000).toOctets(4, Endian.little);
        if(blocsOctets[i].equals(octetsPointeur)){
          imgRom.pointeurs.add(i * 4);
          continue mainloop;
        }
      }
    }
  }
  print("");
}