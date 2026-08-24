# Face authentication app

The app runs `assets/models/face_classifier.tflite` locally on each captured or uploaded image. It displays the result class and confidence, then maps the result as follows:

- `me` or `teammate` -> `class_A`
- `professor` -> `class_B`

For `class_B`, only the just-captured image is AES-GCM encrypted in the app's private documents directory. No Downloads or other user files are accessed.

## Important: verify label order

TFLite does not store the source training-folder labels in this model. The exact exported order is stored in `assets/models/face_classifier_labels.txt`:

```dart
['me', 'professor', 'teammate']
```

The identity label is used internally for the mapping and is not displayed in the app.

## Run

```bash
flutter pub get
flutter run
```
