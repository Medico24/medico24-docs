# ML Development Setup

This guide covers setting up the Medico24 machine learning module for symptom analysis and health predictions.

## Prerequisites

- Python 3.11 or higher
- Jupyter Notebook/Lab
- Git LFS (for large model files)
- CUDA Toolkit (optional, for GPU acceleration)

---

## Installation

### 1. Navigate to ML Directory

```bash
cd medico24-ml
```

### 2. Create Virtual Environment

=== "Windows"
    ```powershell
    python -m venv venv
    .\venv\Scripts\activate
    ```

=== "macOS/Linux"
    ```bash
    python3 -m venv venv
    source venv/bin/activate
    ```

### 3. Install Dependencies

```bash
# Upgrade pip
pip install --upgrade pip

# Install ML dependencies
pip install -e .

# Install development dependencies
pip install -e ".[dev]"

# Install Jupyter
pip install jupyter jupyterlab
```

### 4. Install Git LFS (for large files)

```bash
# Windows (Chocolatey)
choco install git-lfs

# macOS
brew install git-lfs

# Linux
sudo apt-get install git-lfs

# Initialize Git LFS
git lfs install
```

---

## Environment Configuration

### Create `.env` File

```bash
cp .env.example .env
```

### Environment Variables

```env
# Project Configuration
PROJECT_NAME=Medico24 ML
ENVIRONMENT=development
DEBUG=true

# Data Paths
DATA_DIR=data/
RAW_DATA_DIR=data/raw/
PROCESSED_DATA_DIR=data/processed/
MODEL_DIR=models/
LOGS_DIR=logs/

# Model Configuration
MODEL_NAME=symptom_analyzer_v1
MODEL_VERSION=1.0.0
MAX_SEQUENCE_LENGTH=128
EMBEDDING_DIM=256
BATCH_SIZE=32
LEARNING_RATE=0.001
EPOCHS=50

# Training Configuration
TRAIN_TEST_SPLIT=0.2
VALIDATION_SPLIT=0.1
RANDOM_SEED=42
USE_GPU=false  # Set to true if CUDA is available

# MLflow Tracking (optional)
MLFLOW_TRACKING_URI=http://localhost:5000
MLFLOW_EXPERIMENT_NAME=medico24-experiments

# Weights & Biases (optional)
WANDB_PROJECT=medico24-ml
WANDB_API_KEY=your-wandb-api-key

# External APIs
OPENAI_API_KEY=sk-...  # Optional: for enhanced NLP
HUGGINGFACE_TOKEN=hf_...  # Optional: for downloading models

# Database (for storing predictions)
DATABASE_URL=postgresql://user:password@host/database

# Redis (for caching predictions)
REDIS_URL=redis://default:password@host:port/0

# Feature Flags
ENABLE_CACHING=true
ENABLE_LOGGING=true
ENABLE_METRICS=true
```

---

## Project Structure

```
medico24-ml/
├── data/
│   ├── raw/                 # Original datasets
│   ├── processed/           # Cleaned & preprocessed data
│   └── external/           # External datasets
├── models/                  # Trained model files
│   ├── checkpoints/        # Training checkpoints
│   └── production/         # Production models
├── notebooks/               # Jupyter notebooks
│   ├── 01_data_exploration.ipynb
│   ├── 02_preprocessing.ipynb
│   ├── 03_model_training.ipynb
│   └── 04_evaluation.ipynb
├── src/
│   ├── data/               # Data processing scripts
│   │   ├── loaders.py
│   │   ├── preprocessors.py
│   │   └── augmentation.py
│   ├── features/           # Feature engineering
│   │   ├── extractors.py
│   │   └── selectors.py
│   ├── models/             # Model definitions
│   │   ├── symptom_analyzer.py
│   │   ├── risk_predictor.py
│   │   └── base.py
│   ├── training/           # Training scripts
│   │   ├── train.py
│   │   └── evaluate.py
│   ├── inference/          # Inference/prediction
│   │   └── predictor.py
│   └── utils/              # Utilities
│       ├── metrics.py
│       └── visualization.py
├── tests/                   # Unit tests
├── configs/                 # Configuration files
├── docs/                    # ML documentation
├── scripts/                 # Utility scripts
├── pyproject.toml          # Project configuration
├── requirements.txt        # Dependencies (generated)
└── README.md
```

---

## Data Access

### Download Training Data

```bash
# Download from cloud storage (example)
python scripts/download_data.py

# Or manually place datasets in data/raw/
```

### Expected Data Format

```
data/raw/
├── symptoms_dataset.csv
├── diseases_mapping.csv
├── patient_records.csv
└── medical_history.parquet
```

### Data Preprocessing

```bash
# Run preprocessing pipeline
python src/data/preprocessors.py

# Or use the notebook
jupyter notebook notebooks/02_preprocessing.ipynb
```

---

## Running Jupyter Notebooks

### Start Jupyter Lab

```bash
jupyter lab

# Or Jupyter Notebook
jupyter notebook
```

Access at http://localhost:8888

### Execute Notebooks

1. **01_data_exploration.ipynb** - Explore and visualize data
2. **02_preprocessing.ipynb** - Clean and prepare data
3. **03_model_training.ipynb** - Train ML models
4. **04_evaluation.ipynb** - Evaluate model performance

---

## Model Training

### Train a Model

```bash
# Basic training
python src/training/train.py

# With custom config
python src/training/train.py --config configs/symptom_analyzer.yaml

# Resume from checkpoint
python src/training/train.py --resume models/checkpoints/latest.pt
```

### Training Script Example

```python
# src/training/train.py
import torch
from src.models.symptom_analyzer import SymptomAnalyzer
from src.data.loaders import get_data_loaders

def train():
    # Load data
    train_loader, val_loader = get_data_loaders(
        batch_size=32,
        train_split=0.8
    )
    
    # Initialize model
    model = SymptomAnalyzer(
        vocab_size=10000,
        embedding_dim=256,
        hidden_dim=512,
        num_classes=100
    )
    
    # Training loop
    optimizer = torch.optim.Adam(model.parameters(), lr=0.001)
    criterion = torch.nn.CrossEntropyLoss()
    
    for epoch in range(50):
        model.train()
        for batch in train_loader:
            optimizer.zero_grad()
            outputs = model(batch['symptoms'])
            loss = criterion(outputs, batch['labels'])
            loss.backward()
            optimizer.step()
        
        # Validation
        val_loss = evaluate(model, val_loader, criterion)
        print(f'Epoch {epoch}: Val Loss = {val_loss:.4f}')
    
    # Save model
    torch.save(model.state_dict(), 'models/symptom_analyzer.pt')

if __name__ == '__main__':
    train()
```

---

## Model Evaluation

### Evaluate Model

```bash
# Evaluate on test set
python src/training/evaluate.py --model models/symptom_analyzer.pt

# Generate evaluation report
python src/training/evaluate.py --report --output reports/evaluation.html
```

### Metrics

Common metrics tracked:

- **Accuracy**: Overall prediction accuracy
- **Precision/Recall**: Per-class performance
- **F1-Score**: Harmonic mean of precision and recall
- **ROC-AUC**: Area under ROC curve
- **Confusion Matrix**: Detailed classification results

---

## Inference & Prediction

### Make Predictions

```python
# src/inference/predictor.py
from src.models.symptom_analyzer import SymptomAnalyzer
import torch

class SymptomPredictor:
    def __init__(self, model_path):
        self.model = SymptomAnalyzer.load(model_path)
        self.model.eval()
    
    def predict(self, symptoms: list[str]) -> dict:
        with torch.no_grad():
            # Preprocess symptoms
            encoded = self.encode_symptoms(symptoms)
            
            # Predict
            outputs = self.model(encoded)
            probabilities = torch.softmax(outputs, dim=-1)
            
            # Get top predictions
            top_k = torch.topk(probabilities, k=5)
            
            return {
                'predictions': [
                    {
                        'disease': self.id_to_disease[idx.item()],
                        'confidence': prob.item()
                    }
                    for idx, prob in zip(top_k.indices, top_k.values)
                ]
            }
```

### Use in API

```python
# Integration with FastAPI backend
from fastapi import APIRouter
from src.inference.predictor import SymptomPredictor

router = APIRouter()
predictor = SymptomPredictor('models/production/symptom_analyzer.pt')

@router.post('/predict')
def predict_disease(symptoms: list[str]):
    return predictor.predict(symptoms)
```

---

## Experiment Tracking

### MLflow

```bash
# Start MLflow UI
mlflow ui --host 0.0.0.0 --port 5000
```

```python
# Track experiments
import mlflow

with mlflow.start_run():
    mlflow.log_param('learning_rate', 0.001)
    mlflow.log_metric('accuracy', 0.95)
    mlflow.log_artifact('models/symptom_analyzer.pt')
```

### Weights & Biases

```python
import wandb

wandb.init(project='medico24-ml', name='experiment-1')

# Log metrics
wandb.log({'accuracy': 0.95, 'loss': 0.05})

# Log model
wandb.save('models/symptom_analyzer.pt')
```

---

## Testing

### Run Tests

```bash
# Run all tests
pytest

# Run with coverage
pytest --cov=src --cov-report=html

# Run specific tests
pytest tests/test_models.py
```

### Example Test

```python
# tests/test_models.py
import pytest
from src.models.symptom_analyzer import SymptomAnalyzer

def test_model_forward_pass():
    model = SymptomAnalyzer(vocab_size=1000, embedding_dim=128)
    inputs = torch.randint(0, 1000, (32, 50))  # batch_size=32, seq_len=50
    outputs = model(inputs)
    assert outputs.shape == (32, 100)  # num_classes=100
```

---

## Code Quality

### Linting

```bash
# Lint code
ruff check src/

# Auto-fix
ruff check --fix src/
```

### Type Checking

```bash
# Type check with mypy
mypy src/
```

### Formatting

```bash
# Format code
ruff format src/
```

---

## GPU Acceleration

### Check CUDA Availability

```python
import torch

print(f"CUDA available: {torch.cuda.is_available()}")
print(f"CUDA device count: {torch.cuda.device_count()}")
print(f"Current device: {torch.cuda.current_device()}")
```

### Install PyTorch with CUDA

```bash
# For CUDA 11.8
pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu118

# For CUDA 12.1
pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu121
```

### Use GPU in Training

```python
device = torch.device('cuda' if torch.cuda.is_available() else 'cpu')
model = model.to(device)

for batch in train_loader:
    inputs = batch['symptoms'].to(device)
    labels = batch['labels'].to(device)
    # ...
```

---

## Model Deployment

### Export to ONNX

```python
import torch

# Load model
model = SymptomAnalyzer.load('models/symptom_analyzer.pt')
model.eval()

# Export to ONNX
dummy_input = torch.randint(0, 1000, (1, 50))
torch.onnx.export(
    model,
    dummy_input,
    'models/symptom_analyzer.onnx',
    input_names=['symptoms'],
    output_names=['predictions'],
    dynamic_axes={'symptoms': {0: 'batch_size'}}
)
```

### Quantization (Reduce Model Size)

```python
import torch

model = SymptomAnalyzer.load('models/symptom_analyzer.pt')

# Dynamic quantization
quantized_model = torch.quantization.quantize_dynamic(
    model,
    {torch.nn.Linear},
    dtype=torch.qint8
)

torch.save(quantized_model.state_dict(), 'models/symptom_analyzer_quantized.pt')
```

### Serve with FastAPI

```python
from fastapi import FastAPI
from src.inference.predictor import SymptomPredictor

app = FastAPI()
predictor = SymptomPredictor('models/production/symptom_analyzer.pt')

@app.post('/api/v1/ml/predict')
async def predict(symptoms: list[str]):
    return predictor.predict(symptoms)
```

---

## Monitoring & Logging

### Setup Logging

```python
import logging

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('logs/training.log'),
        logging.StreamHandler()
    ]
)

logger = logging.getLogger(__name__)
logger.info('Training started')
```

### Log Predictions

```python
# Store predictions for monitoring
import redis

redis_client = redis.from_url(os.getenv('REDIS_URL'))

def log_prediction(symptoms, prediction):
    redis_client.lpush('predictions', json.dumps({
        'symptoms': symptoms,
        'prediction': prediction,
        'timestamp': datetime.now().isoformat()
    }))
```

---

## Common ML Tasks

### Feature Engineering

```python
# src/features/extractors.py
from sklearn.feature_extraction.text import TfidfVectorizer

class SymptomFeatureExtractor:
    def __init__(self):
        self.vectorizer = TfidfVectorizer(max_features=1000)
    
    def fit_transform(self, symptoms: list[str]):
        return self.vectorizer.fit_transform(symptoms)
    
    def transform(self, symptoms: list[str]):
        return self.vectorizer.transform(symptoms)
```

### Hyperparameter Tuning

```python
from sklearn.model_selection import GridSearchCV

param_grid = {
    'learning_rate': [0.001, 0.01, 0.1],
    'batch_size': [16, 32, 64],
    'hidden_dim': [128, 256, 512]
}

# Run grid search
best_params = grid_search(model, param_grid, train_data)
```

### Data Augmentation

```python
# src/data/augmentation.py
import nlpaug.augmenter.word as naw

class SymptomAugmenter:
    def __init__(self):
        self.aug = naw.SynonymAug(aug_src='wordnet')
    
    def augment(self, text: str, n: int = 3):
        return [self.aug.augment(text) for _ in range(n)]
```

---

## Troubleshooting

### Out of Memory (OOM)

```python
# Reduce batch size
BATCH_SIZE = 16  # Instead of 32

# Use gradient accumulation
for i, batch in enumerate(train_loader):
    loss = loss / accumulation_steps
    loss.backward()
    
    if (i + 1) % accumulation_steps == 0:
        optimizer.step()
        optimizer.zero_grad()
```

### Slow Training

- Use GPU if available
- Increase batch size
- Use mixed precision training (AMP)
- Profile code to find bottlenecks

### Model Not Converging

- Adjust learning rate
- Try different optimizer (Adam, SGD, AdamW)
- Add regularization (dropout, L2)
- Check for data leakage

---

## Resources & Documentation

- [PyTorch Documentation](https://pytorch.org/docs/)
- [Scikit-learn Guide](https://scikit-learn.org/stable/)
- [Hugging Face Transformers](https://huggingface.co/docs/transformers/)
- [MLflow Documentation](https://mlflow.org/docs/latest/index.html)

---

## Next Steps

1. Explore the notebooks in `notebooks/`
2. Train your first model
3. Integrate with [Backend API](backend-setup.md)
4. Set up experiment tracking with MLflow
5. Read [ML Roadmap](../../roadmap/ml-roadmap.md)

**Related Guides:**

- [Setup Overview](overview.md)
- [Backend Setup](backend-setup.md)
- [ML Roadmap](../../roadmap/ml-roadmap.md)
