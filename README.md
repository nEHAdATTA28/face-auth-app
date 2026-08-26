# Face authentication app

A controlled academic Computer Systems Security project demonstrating how a
face-classification model can be connected to application behaviour inside an
isolated Android emulator.

The system uses a synthetic face dataset, a MobileNetV3Large transfer-learning
classifier, TensorFlow Lite deployment, and a Flutter Android application.

## 1. Project Overview

This project studies the security risks of connecting biometric face
classification directly to a sensitive application action.

The system recognises three identity labels:

- `me`
- `teammate`
- `professor`

The application then maps these identities to two operational classes:

- **Class A** → `me` or `teammate`
- **Class B** → `professor`

The face classifier itself predicts the identity label. The mapping from
identity to Class A/Class B is performed by the application logic after
inference.

The final model is exported as a TensorFlow Lite model and executed locally
inside an Android emulator.

---

## 2. Objectives

The main objectives of the project are:

1. Generate a reproducible synthetic face dataset from a single reference
   image per identity.
2. Apply conventional image augmentation.
3. Train a lightweight face-classification model suitable for mobile
   deployment.
4. Export the trained model to TensorFlow Lite.
5. Integrate the model into a Flutter Android application.
6. Support both live camera capture and image upload.
7. Display the predicted identity, class and model confidence.
8. Demonstrate two different application paths based on the classification
   result.
9. Evaluate model performance and discuss limitations caused by synthetic data.
10. Demonstrate the security implications of coupling biometric classification
    with sensitive system actions in a controlled environment.

---

## 3. System Architecture

The overall application pipeline is:

Camera Capture / Uploaded Image
        ↓
Face Detection
        ↓
Face Crop + Padding
        ↓
Resize to 224 × 224
        ↓
MobileNetV3Large
        ↓
Softmax Prediction
        ↓
Identity Prediction
        ↓
Class A / Class B Mapping
        ↓
Application Response

The model predicts one of:

- `me`
- `professor`
- `teammate`

The application subsequently maps these identities to Class A or Class B.

---

## 4. Dataset
The reference images used for generating the synthetic dataset are as follows:
Me: 
![alt text](Images/reference_me.jpg)

Teammate: 
![alt text](Images/reference_teammate.jpg)

Professor: 
![alt text](Images/reference_professor.png)
The project uses three identity classes:

| Identity | Operational Class |
|----------|-------------------|
| me | Class A |
| teammate | Class A |
| professor | Class B |

Each identity contains 500 final images after synthetic generation and
conventional augmentation.

### Final Dataset Composition

| Identity | Train | Validation | Test | Total |
|----------|------:|-----------:|-----:|------:|
| Me | 400 | 50 | 50 | 500 |
| Teammate | 400 | 50 | 50 | 500 |
| Professor | 400 | 50 | 50 | 500 |
| **Total** | **1200** | **150** | **150** | **1500** |

The dataset therefore contains:

- 750 synthetic originals
- 1,500 images after augmentation
- 1,200 training images
- 150 validation images
- 150 test images

The original train/validation/test split was performed before augmentation
to avoid data leakage.

---

## 5. Synthetic Dataset Generation

Only one reference photograph was available for each identity.

To create additional training examples, Stable Diffusion v1.5 was used in
image-to-image mode.

The pipeline used:

- Stable Diffusion v1.5
- `StableDiffusionImg2ImgPipeline`
- `float16` precision
- Image-to-image generation
- 250 synthetic originals per identity
- 10 prompts per identity
- Deterministic seeds
- Controlled variation in lighting, age, pose and framing

Image-to-image generation was selected instead of text-to-image generation
because the reference photograph provides the identity information that
should be preserved while introducing controlled variations.

### Synthetic Generation Hyperparameters

| Parameter | Value |
|-----------|-------|
| Base model | `runwayml/stable-diffusion-v1-5` |
| Pipeline | `StableDiffusionImg2ImgPipeline` |
| Precision | `float16` |
| Input size | Thumbnail fitted within 512 × 512 |
| Default strength | 0.15 |
| Head-turn strength | 0.25 |
| Guidance scale | 7.0 |
| Inference steps | 30 |
| Prompts per identity | 10 |
| Synthetic originals per identity | 250 |
| Total synthetic originals | 750 |
| Seed | `10000 + i` |
| Safety checker | Disabled for controlled offline research |

### Generated Variations

The prompts covered:

- Current appearance
- Slightly younger appearance
- Slightly older appearance
- Bright indoor lighting
- Dim indoor lighting
- Natural daylight
- Three-quarter left view
- Three-quarter right view
- Different camera distances
- Different framing conditions

The professor class additionally used ageing-oriented prompts to increase
visual variation.

A shared negative prompt was used to reduce:

- Identity drift
- Different facial structure
- Deformed faces
- Blurry outputs
- Cartoon-like outputs
- Plastic-looking skin
- Excessive ageing

---

## 6. Dataset Splitting

The dataset was split before conventional augmentation.

For each identity:

- 200 synthetic originals → training
- 25 synthetic originals → validation
- 25 synthetic originals → test

This corresponds to:

- 80% training
- 10% validation
- 10% test

The split was performed using deterministic random seeds and stratification
based on prompt index.

This prevents augmented versions of the same source image from appearing
across different dataset splits.

---

## 7. Conventional Augmentation

After the dataset split was fixed, one deterministic augmentation was paired
with every original image.

The augmentation operations included:

- Horizontal flip
- Brightness jitter
- Rotation
- Gaussian noise

### Augmentation Settings

| Augmentation | Setting |
|--------------|---------|
| Horizontal flip | Applied deterministically |
| Brightness limit | 0.20 |
| Contrast limit | 0.0 |
| Rotation | Up to ±15° |
| Border mode | Reflect-101 |
| Gaussian noise | Standard deviation 0.02–0.08 |

The augmentation was applied within each dataset split so that no augmented
image crossed between training, validation and test sets.

---

## 8. Model

The project uses **MobileNetV3Large** with ImageNet-pretrained weights.

MobileNetV3Large was selected because it provides a practical balance
between classification performance and mobile deployment requirements.

### Model Configuration

| Parameter | Value |
|-----------|-------|
| Model | MobileNetV3Large |
| Pretrained weights | ImageNet |
| Input size | 224 × 224 × 3 |
| Batch size | 32 |
| Optimizer | AdamW |
| Loss | SparseCategoricalCrossentropy |
| Dropout | 0.40 |
| Output activation | Softmax |
| Deployment format | Float32 TensorFlow Lite |
| Total parameters | 2,999,235 |

---

## 9. Two-Stage Fine-Tuning

Training was performed in two stages.

### Stage 1 — Frozen Feature Extraction

The MobileNetV3Large backbone was frozen and only the classification head
was trained.

Settings:

- Learning rate: `1e-3`
- Weight decay: `1e-4`
- Maximum epochs: 30
- Optimizer: AdamW
- Loss: SparseCategoricalCrossentropy

This allowed the classification head to adapt to the three identities while
preserving the pretrained ImageNet features.

### Stage 2 — Partial Fine-Tuning

The final 35 layers of the MobileNetV3Large backbone were unfrozen.

Settings:

- Learning rate: `1e-5`
- Weight decay: `1e-5`
- Maximum epochs: 20
- Unfrozen layers: final 35 base layers
- Learning-rate reduction factor: 0.3
- Learning-rate scheduler patience: 3 epochs
- Early stopping patience: 7 epochs

The lower learning rate was used to reduce the risk of catastrophic
forgetting during fine-tuning.

---

## 10. Model Export

After training, the Keras model was converted to a Float32 TensorFlow Lite
model.

The TFLite model is bundled with the Flutter application and performs
inference locally.

Example application asset:

```text
assets/
└── models/
    ├── face_classifier.tflite
    └── face_classifier_labels.txt

## Run

```bash
flutter pub get
flutter run
```
