package com.example.unittest;

import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.graphics.Canvas;
import android.graphics.Color;
import android.graphics.ColorMatrix;
import android.graphics.ColorMatrixColorFilter;
import android.graphics.Paint;
import android.util.Log;
import java.io.ByteArrayOutputStream;
import java.io.IOException;

public class CoverIMG {

  private static final String TAG = "CoverIMG";

  /**
   * Converts a raw image byte array (e.g., PNG, JPEG) to a 1-bit monochrome byte array
   * suitable for ESC/POS raster bit image printing (GS v 0 command).
   * The image will be resized to the target width and converted to black and white using a simple threshold.
   *
   * @param imageData Raw image bytes (e.g., from an asset or file).
   * @param targetWidth The desired width of the image in pixels for printing.
   * @return A byte array containing the ESC/POS command and image data, or null if processing fails.
   */
  public static byte[] processImageForPrinter(
    byte[] imageData,
    int targetWidth
  ) {
    if (imageData == null || imageData.length == 0) {
      Log.e(TAG, "Input image data is empty or null.");
      return null;
    }
    if (targetWidth <= 0) {
      Log.e(TAG, "Target width must be positive.");
      return null;
    }

    try {
      // 1. Decode image data to Bitmap
      Bitmap originalBitmap = BitmapFactory.decodeByteArray(
        imageData,
        0,
        imageData.length
      );
      if (originalBitmap == null) {
        Log.e(TAG, "Failed to decode image data into Bitmap.");
        return null;
      }

      // 2. Resize Bitmap to targetWidth, maintaining aspect ratio
      int originalWidth = originalBitmap.getWidth();
      int originalHeight = originalBitmap.getHeight();
      int scaledHeight = (int) (originalHeight *
        ((float) targetWidth / originalWidth));
      if (scaledHeight % 2 != 0) {
        scaledHeight++;
      }

      Bitmap scaledBitmap = Bitmap.createScaledBitmap(
        originalBitmap,
        targetWidth,
        scaledHeight,
        true
      );
      originalBitmap.recycle();

      // 3. Convert to Grayscale (intermediate step for better monochrome conversion)
      Bitmap grayscaleBitmap = Bitmap.createBitmap(
        targetWidth,
        scaledHeight,
        Bitmap.Config.ARGB_8888
      );
      Canvas canvas = new Canvas(grayscaleBitmap);
      ColorMatrix colorMatrix = new ColorMatrix();
      colorMatrix.setSaturation(0);
      ColorMatrixColorFilter filter = new ColorMatrixColorFilter(colorMatrix);
      Paint paint = new Paint();
      paint.setColorFilter(filter);
      canvas.drawBitmap(scaledBitmap, 0, 0, paint);
      scaledBitmap.recycle();

      // 4. Convert to 1-bit monochrome (black and white)
      int widthBytes = (targetWidth + 7) / 8;
      int height = scaledHeight;
      byte[] pixels = new byte[widthBytes * height];
      int[] colors = new int[targetWidth * height];

      grayscaleBitmap.getPixels(
        colors,
        0,
        targetWidth,
        0,
        0,
        targetWidth,
        height
      );
      grayscaleBitmap.recycle();

      for (int y = 0; y < height; y++) {
        for (int x = 0; x < targetWidth; x++) {
          int pixelColor = colors[y * targetWidth + x];
          int gray =
            (Color.red(pixelColor) +
              Color.green(pixelColor) +
              Color.blue(pixelColor)) /
            3;
          if (gray < 128) {
            pixels[y * widthBytes + x / 8] |= (byte) (0x80 >> (x % 8));
          }
        }
      }

      // 5. Construct ESC/POS Raster Bit Image Command (GS v 0)
      ByteArrayOutputStream commandStream = new ByteArrayOutputStream();

      commandStream.write(0x1D); // GS
      commandStream.write(0x76); // v
      commandStream.write(0x30); // 0
      commandStream.write(0x00); // p (mode 0x00: normal 1-bit per pixel)

      commandStream.write(widthBytes & 0xFF);
      commandStream.write((widthBytes >> 8) & 0xFF);

      commandStream.write(height & 0xFF);
      commandStream.write((height >> 8) & 0xFF);

      commandStream.write(pixels);

      return commandStream.toByteArray();
    } catch (Exception e) {
      Log.e(TAG, "Error processing image for printer: " + e.getMessage());
      e.printStackTrace();
      return null;
    }
  }
}
