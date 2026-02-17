import 'dart:typed_data';
import 'package:image/image.dart' as img;

class SteganographyService {
  /// Hides [secret] message inside [imageBytes].
  /// Returns the modified image bytes.
  static Uint8List encode(Uint8List imageBytes, String secret) {
    img.Image? image = img.decodeImage(imageBytes);
    if (image == null) return imageBytes;

    // Convert secret to bits
    List<int> secretBytes = List<int>.from(secret.codeUnits);
    // Add null terminator to know where to stop
    secretBytes.add(0);
    
    List<int> bits = [];
    for (var byte in secretBytes) {
      for (var i = 7; i >= 0; i--) {
        bits.add((byte >> i) & 1);
      }
    }

    int bitIndex = 0;
    
    // Iterate through pixels and replace LSB of color channels
    outerLoop:
    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        var pixel = image.getPixel(x, y);
        
        // We use R, G, B channels. 3 bits per pixel.
        List<int> channels = [pixel.r.toInt(), pixel.g.toInt(), pixel.b.toInt()];
        
        for (int c = 0; c < 3; c++) {
          if (bitIndex >= bits.length) break outerLoop;
          
          // Clear LSB and set it to secret bit
          channels[c] = (channels[c] & ~1) | bits[bitIndex];
          bitIndex++;
        }
        
        image.setPixelRgb(x, y, channels[0], channels[1], channels[2]);
      }
    }

    return Uint8List.fromList(img.encodePng(image));
  }

  /// Extracts the hidden message from [imageBytes].
  static String decode(Uint8List imageBytes) {
    img.Image? image = img.decodeImage(imageBytes);
    if (image == null) return "";

    List<int> bits = [];
    
    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        var pixel = image.getPixel(x, y);
        List<int> channels = [pixel.r.toInt(), pixel.g.toInt(), pixel.b.toInt()];
        
        for (int c = 0; c < 3; c++) {
          bits.add(channels[c] & 1);
        }
      }
    }

    List<int> secretBytes = [];
    for (int i = 0; i < bits.length; i += 8) {
      if (i + 8 > bits.length) break;
      
      int byte = 0;
      for (int bit = 0; bit < 8; bit++) {
        byte = (byte << 1) | bits[i + bit];
      }
      
      if (byte == 0) break; // Null terminator found
      secretBytes.add(byte);
    }

    return String.fromCharCodes(secretBytes);
  }
}
