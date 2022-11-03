// ignore_for_file: constant_identifier_names, non_constant_identifier_names, unnecessary_this
import "dart:typed_data";
import "dart:io";
import "package:collection/collection.dart";
import "outils.dart";

enum GenrePix{
  avecLignes,
  dejaEncode,
  avecChunks,
  sansLignes;
}

class Bitmap{
  /* Taille des blocs */
  final int sizeofBitmapFileHeader = 14;
  final int sizeofBitmapInformationHeader = 40;
  late int sizeofColorTable;
  late int sizeofPixelArray;

  late int rowSize;
  late List<int> ColorTable;

  bool estPhotoshop = false;

  // Bitmap File Header : 14 octets
  final String Signature = "BM";
  late int FileSize;
  final int Reserved = 0;
  final int DataOffset = 0x0436;

  // Bitmap Information Header : 40 octets
  final int InfoHeaderSize = 40;
  late int Width;
  late int Height;
  final int Planes = 1;
  final int BitsPerPixel = 8; //On assume pour avoir 256 couleurs
  final int Compression = 0;
  final int ImageSize = 0;  // On a le droit de mettre 0 car Commpression == 0
  final int XpixelsPerM = 3779; //2835 = 72 DPI × 39.3701 | 3779 = 96 DPI x 39.3701 arrondi au plus proche: pouces par mètre
  final int YpixelsPerM = 3779;
  final int ColorsUsed = 256; // On assume 256 couleurs utilisées
  final int ImportantColors = 0;

  // Color Table : 4 * NumColors octets (ici 4 * 256)
  static final List<List<int>> palSprite = lirePal256(Global.cheminPalSprite);
  static final List<List<int>> palBackground = lirePal256(Global.cheminPalBackground);

  // Pixel Array : ImageSizes octets (mais 0 possible donc à calculer)
  List<int> PixelArray = [];

  List<int> bmpOctets = [];

  Bitmap({required Object inputPix, required GenrePix genrePix, required String pal, required this.Width, required this.Height, required this.estPhotoshop}){
    calculerRowSize();
    calculerPixelArraySize();
    calculerFileSize();

    switch(genrePix){
      case GenrePix.sansLignes : encoderPixelArray_sansLignes(inputPix as List<int>, Width);break;
      case GenrePix.avecLignes : encoderPixelArray_avecLignes(inputPix as List<List<int>>);break;
      case GenrePix.dejaEncode : encodePixelArray_dejaEncode(inputPix as List<int>);break;
      case GenrePix.avecChunks: encodePixelArray_avecChunks(inputPix as List<int>);break;
    }

    switch(pal){
      case "sprite" : encoderPal(palSprite);break;
      case "background" :encoderPal(palBackground);break;
    }

    genererOctets();
  }


  List<int> genererOctets(){
    bmpOctets.clear();
    bmpOctets =
      Signature.codeUnits +
      FileSize.toOctets(4, Endian.little) +
      Reserved.toOctets(4, Endian.little) +
      DataOffset.toOctets(4, Endian.little) +

      InfoHeaderSize.toOctets(4, Endian.little) +
      Width.toOctets(4, Endian.little) +
      Height.toOctets(4, Endian.little) +
      Planes.toOctets(2, Endian.little) +
      BitsPerPixel.toOctets(2, Endian.little) +
      Compression.toOctets(4, Endian.little) +
      ImageSize.toOctets(4, Endian.little) +
      XpixelsPerM.toOctets(4, Endian.little) +
      YpixelsPerM.toOctets(4, Endian.little) +
      ColorsUsed.toOctets(4, Endian.little) +
      ImportantColors.toOctets(4, Endian.little) +

      ColorTable +

      PixelArray;

    return bmpOctets;
  }

  void calculerFileSize(){
    sizeofColorTable = 4* 256;
    FileSize = sizeofBitmapFileHeader + sizeofBitmapInformationHeader + sizeofColorTable + sizeofPixelArray;
  }

  void calculerRowSize () => rowSize = (8*Width/32).ceil() * 4;
  void calculerPixelArraySize(){
    sizeofPixelArray = rowSize * Height.abs();
    if(estPhotoshop){
      sizeofPixelArray += 2;
    }
  }

  static List<List<int>> lirePal256(String nomFicPal){
    /*
    File format
    As like every other RIFF file, the PAL files start off with the RIFF header:

    4-byte RIFF signature "RIFF"
    4-byte file length in bytes (excluding the RIFF header)
    4-byte PAL signature "PAL " (note the space / 0x20 at the end)
    The PAL files then include 4 different chunks, of which only the "data" chunk is important. The other chunks "offl", "tran" and "unde" are all 32 bytes long, filled with 0x00. Their purpose remains unknown since they can be deleted and the game still accepts the PAL files. Like other RIFF chunks, the data chunk starts with its signature and length:

    4-byte data chunk signature "data"
    4-byte data chunk size excluding the chunk header
    2-byte PAL version. This version is always 0x0300.
    2-byte color entry count. This determines how many colors are following.
    Each color consists of 4 bytes holding the following data:

    1-byte red amount of color
    1-byte green amount of color
    1-byte blue amount of color
    1-byte "flags" - W:A PAL files always have the 0x00 flag, so no flag is set.

    */
    List<int> pal = File(nomFicPal).readAsBytesSync();
    List<List<int>> listeCouleurs = [];
    int posDebutCouleurs = 0x18;
    for (int i = posDebutCouleurs ; i < pal.length ; i+=4){
      listeCouleurs.add([pal[i], pal[i+1], pal[i+2]]);
    }
    return listeCouleurs;
  }

  void encoderPal(List<List<int>> pal){
    ColorTable = [];
    for (List<int> rgbCoul in pal){
      ColorTable.addAll(rgbCoul.reversed.toList() + [0]);
    }
  }

  void encoderPixelArray_sansLignes(List<int> octets, int largeur){
    PixelArray.clear();
    List<List<int>> lignes = octets.slices(largeur).toList();
    lignes = lignes.reversed.toList();
    int nbPad = rowSize - Width;
    for(List<int> ligne in lignes){
      PixelArray.addAll(ligne + List.filled(nbPad, 0));
    }
  }

  void encoderPixelArray_avecLignes(List<List<int>> lignes){
    PixelArray.clear();
    lignes = lignes.reversed.toList();
    int nbPad = rowSize - Width;
    for(List<int> ligne in lignes){
      PixelArray.addAll(ligne + List.filled(nbPad, 0));
    }
  }
  void encodePixelArray_dejaEncode(List<int> octets){
    PixelArray = octets.toList();
  }

  void encodePixelArray_avecChunks(List<int> octets){
    // Correction tilesets non remplis
    if(octets.length < (Width * Height)){
      octets = octets + List<int>.filled((Width * Height) - octets.length, 0);
    }

    final int tailleTuile = 8 * 8;
    int tailleBlock = Width * 8;
    List<List<int>> blocsLigne = octets.slices(tailleBlock).toList();

    List<List<int>> tuileArrange = [];
    for(int b = 0; b < blocsLigne.length; b ++ ){
      List<int> unbloc  = blocsLigne[b].toList();
      List<List<int>> listeTuiles = unbloc.slices(tailleTuile).toList();
      for(int i = 0; i < tailleTuile ; i+=8 ){
        List<int> ligne = [];
        for (int j = 0; j < listeTuiles.length; j++){
          ligne.addAll(listeTuiles[j].sublist(i, i+8));
        }
        tuileArrange.add(ligne);
      }
    }
    encoderPixelArray_avecLignes(tuileArrange);
  }
}

