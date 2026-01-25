# Machine Learning Module Guide

This guide covers the machine learning and AI components of the Medico24 platform, including predictive analytics, health insights, and data processing pipelines.

## Overview

The Medico24 ML module provides intelligent healthcare insights through:

- **Health Risk Assessment** - Predictive models for health risk factors
- **Appointment Optimization** - Smart scheduling and resource allocation
- **Environmental Health Analysis** - Correlation of environmental data with health outcomes
- **Pharmacy Recommendation** - Intelligent pharmacy suggestions based on location and services
- **Data Analytics** - Comprehensive healthcare data analysis

## Architecture

### Project Structure

```
medico24-ml/
├── src/                      # Source code
│   ├── models/               # ML model implementations
│   ├── pipelines/            # Data processing pipelines
│   ├── features/             # Feature engineering
│   ├── evaluation/           # Model evaluation
│   └── deployment/           # Model deployment
├── notebooks/                # Jupyter notebooks
│   ├── exploration/          # Data exploration
│   ├── experiments/          # Model experiments
│   └── analysis/             # Data analysis
├── data/                     # Data storage
│   ├── raw/                  # Raw data files
│   ├── processed/            # Processed datasets
│   └── external/             # External datasets
├── models/                   # Trained model artifacts
├── tests/                    # Test suite
├── docs/                     # Documentation
└── requirements.txt          # Dependencies
```

### Technology Stack

| Component | Technology | Purpose |
|-----------|------------|---------|
| **ML Framework** | scikit-learn, PyTorch | Model development |
| **Data Processing** | pandas, numpy | Data manipulation |
| **Visualization** | matplotlib, seaborn, plotly | Data visualization |
| **Notebooks** | Jupyter Lab | Interactive development |
| **Model Serving** | MLflow, FastAPI | Model deployment |
| **Data Storage** | PostgreSQL, S3 | Data persistence |
| **Monitoring** | MLflow, Prometheus | Model monitoring |

## Development Setup

### Prerequisites

- Python 3.9+
- pip or conda
- Jupyter Lab
- Git

### Environment Setup

```bash
# Clone repository
git clone https://github.com/medico24/medico24-ml.git
cd medico24-ml

# Create virtual environment
python -m venv .venv

# Activate virtual environment
# Windows
.venv\Scripts\activate
# macOS/Linux
source .venv/bin/activate

# Install dependencies
pip install -r requirements.txt

# Install development dependencies
pip install -r requirements-dev.txt

# Install package in development mode
pip install -e .
```

### Jupyter Setup

```bash
# Install Jupyter Lab
pip install jupyterlab

# Install kernel
python -m ipykernel install --user --name medico24-ml --display-name "Medico24 ML"

# Start Jupyter Lab
jupyter lab
```

## Core Components

### 1. Health Risk Assessment

```python
# src/models/health_risk_model.py
import pandas as pd
from sklearn.ensemble import RandomForestClassifier
from sklearn.preprocessing import StandardScaler
from typing import Dict, List

class HealthRiskModel:
    """Health risk assessment model."""
    
    def __init__(self):
        self.model = RandomForestClassifier(n_estimators=100, random_state=42)
        self.scaler = StandardScaler()
        self.features = [
            'age', 'bmi', 'blood_pressure_systolic', 'blood_pressure_diastolic',
            'cholesterol', 'glucose', 'smoking', 'physical_activity',
            'family_history', 'environmental_exposure'
        ]
    
    def preprocess(self, data: pd.DataFrame) -> pd.DataFrame:
        """Preprocess input data."""
        # Handle missing values
        data = data.fillna(data.median(numeric_only=True))
        
        # Feature engineering
        data['bmi_category'] = pd.cut(data['bmi'], 
                                     bins=[0, 18.5, 25, 30, float('inf')],
                                     labels=['underweight', 'normal', 'overweight', 'obese'])
        
        data['age_group'] = pd.cut(data['age'],
                                  bins=[0, 30, 50, 70, float('inf')],
                                  labels=['young', 'middle', 'senior', 'elderly'])
        
        return data
    
    def train(self, X: pd.DataFrame, y: pd.Series) -> None:
        """Train the health risk model."""
        X_processed = self.preprocess(X)
        X_scaled = self.scaler.fit_transform(X_processed[self.features])
        
        self.model.fit(X_scaled, y)
    
    def predict_risk(self, patient_data: Dict) -> Dict:
        """Predict health risk for a patient."""
        df = pd.DataFrame([patient_data])
        X_processed = self.preprocess(df)
        X_scaled = self.scaler.transform(X_processed[self.features])
        
        risk_probability = self.model.predict_proba(X_scaled)[0]
        risk_level = self.model.predict(X_scaled)[0]
        
        return {
            'risk_level': risk_level,
            'risk_probability': {
                'low': risk_probability[0],
                'moderate': risk_probability[1],
                'high': risk_probability[2]
            },
            'recommendations': self._generate_recommendations(patient_data, risk_level)
        }
    
    def _generate_recommendations(self, patient_data: Dict, risk_level: str) -> List[str]:
        """Generate health recommendations based on risk assessment."""
        recommendations = []
        
        if risk_level == 'high':
            recommendations.append("Schedule immediate consultation with healthcare provider")
            recommendations.append("Consider comprehensive health screening")
        
        if patient_data.get('bmi', 0) > 30:
            recommendations.append("Consider weight management program")
        
        if patient_data.get('smoking', False):
            recommendations.append("Smoking cessation program recommended")
        
        if patient_data.get('physical_activity', 0) < 3:
            recommendations.append("Increase physical activity to at least 150 minutes per week")
        
        return recommendations
```

### 2. Environmental Health Analysis

```python
# src/models/environmental_health_model.py
import pandas as pd
import numpy as np
from sklearn.linear_model import LinearRegression
from sklearn.preprocessing import PolynomialFeatures

class EnvironmentalHealthModel:
    """Model for analyzing environmental impact on health."""
    
    def __init__(self):
        self.aqi_impact_model = LinearRegression()
        self.weather_impact_model = LinearRegression()
        self.poly_features = PolynomialFeatures(degree=2)
    
    def analyze_aqi_impact(self, aqi_data: pd.DataFrame, 
                          health_incidents: pd.DataFrame) -> Dict:
        """Analyze AQI impact on health incidents."""
        # Merge data on date and location
        merged_data = pd.merge(aqi_data, health_incidents, 
                              on=['date', 'location'], how='inner')
        
        # Feature engineering
        merged_data['aqi_squared'] = merged_data['aqi'] ** 2
        merged_data['aqi_category_encoded'] = merged_data['aqi_category'].map({
            'Good': 1, 'Moderate': 2, 'Unhealthy for Sensitive Groups': 3,
            'Unhealthy': 4, 'Very Unhealthy': 5, 'Hazardous': 6
        })
        
        # Train model
        features = ['aqi', 'aqi_squared', 'aqi_category_encoded']
        X = merged_data[features]
        y = merged_data['incident_count']
        
        self.aqi_impact_model.fit(X, y)
        
        # Calculate correlation and impact scores
        correlation = np.corrcoef(merged_data['aqi'], merged_data['incident_count'])[0, 1]
        
        return {
            'correlation': correlation,
            'r2_score': self.aqi_impact_model.score(X, y),
            'coefficients': dict(zip(features, self.aqi_impact_model.coef_)),
            'interpretation': self._interpret_aqi_impact(correlation)
        }
    
    def predict_health_risk_from_environment(self, environmental_data: Dict) -> Dict:
        """Predict health risks based on environmental conditions."""
        aqi = environmental_data['aqi']
        temperature = environmental_data['temperature']
        humidity = environmental_data.get('humidity', 50)
        
        # Calculate base risk from AQI
        if aqi <= 50:
            base_risk = 0.1
        elif aqi <= 100:
            base_risk = 0.3
        elif aqi <= 150:
            base_risk = 0.5
        elif aqi <= 200:
            base_risk = 0.7
        else:
            base_risk = 0.9
        
        # Adjust for temperature extremes
        if temperature < 0 or temperature > 35:
            base_risk += 0.1
        
        # Adjust for high humidity
        if humidity > 80:
            base_risk += 0.05
        
        risk_score = min(base_risk, 1.0)
        
        return {
            'risk_score': risk_score,
            'risk_level': self._categorize_risk(risk_score),
            'recommendations': self._get_environmental_recommendations(environmental_data)
        }
    
    def _categorize_risk(self, risk_score: float) -> str:
        """Categorize risk score into levels."""
        if risk_score < 0.3:
            return 'Low'
        elif risk_score < 0.6:
            return 'Moderate'
        else:
            return 'High'
    
    def _get_environmental_recommendations(self, env_data: Dict) -> List[str]:
        """Get recommendations based on environmental conditions."""
        recommendations = []
        
        aqi = env_data['aqi']
        if aqi > 100:
            recommendations.append("Limit outdoor activities")
            recommendations.append("Use air purifier indoors")
            recommendations.append("Wear N95 mask when outdoors")
        
        temperature = env_data['temperature']
        if temperature > 30:
            recommendations.append("Stay hydrated")
            recommendations.append("Avoid prolonged sun exposure")
        elif temperature < 5:
            recommendations.append("Dress warmly")
            recommendations.append("Be cautious of hypothermia risk")
        
        return recommendations
```

### 3. Appointment Optimization

```python
# src/models/appointment_optimizer.py
import pandas as pd
import numpy as np
from datetime import datetime, timedelta
from typing import Dict, List, Tuple

class AppointmentOptimizer:
    """Optimize appointment scheduling using ML."""
    
    def __init__(self):
        self.historical_data = None
        self.demand_patterns = {}
        self.cancellation_patterns = {}
    
    def analyze_demand_patterns(self, appointments_data: pd.DataFrame) -> Dict:
        """Analyze historical appointment demand patterns."""
        appointments_data['hour'] = pd.to_datetime(appointments_data['appointment_at']).dt.hour
        appointments_data['day_of_week'] = pd.to_datetime(appointments_data['appointment_at']).dt.dayofweek
        appointments_data['month'] = pd.to_datetime(appointments_data['appointment_at']).dt.month
        
        # Hourly demand patterns
        hourly_demand = appointments_data.groupby('hour').size()
        
        # Daily demand patterns
        daily_demand = appointments_data.groupby('day_of_week').size()
        
        # Monthly demand patterns
        monthly_demand = appointments_data.groupby('month').size()
        
        self.demand_patterns = {
            'hourly': hourly_demand.to_dict(),
            'daily': daily_demand.to_dict(),
            'monthly': monthly_demand.to_dict()
        }
        
        return self.demand_patterns
    
    def predict_cancellation_probability(self, appointment_data: Dict) -> float:
        """Predict probability of appointment cancellation."""
        # Simple heuristic model (can be replaced with ML model)
        base_probability = 0.15
        
        # Adjust based on advance booking time
        days_ahead = (pd.to_datetime(appointment_data['appointment_at']) - 
                     pd.to_datetime(appointment_data['created_at'])).days
        
        if days_ahead > 30:
            base_probability += 0.1
        elif days_ahead < 2:
            base_probability -= 0.05
        
        # Adjust based on appointment type
        if appointment_data.get('reason') == 'routine_checkup':
            base_probability += 0.05
        elif appointment_data.get('reason') == 'emergency':
            base_probability -= 0.1
        
        # Adjust based on patient history
        if appointment_data.get('patient_cancellation_history', 0) > 0.2:
            base_probability += 0.15
        
        return min(max(base_probability, 0), 1)
    
    def optimize_schedule(self, available_slots: List[Dict], 
                         appointment_requests: List[Dict]) -> List[Dict]:
        """Optimize appointment scheduling."""
        optimized_schedule = []
        
        # Sort requests by priority and preferences
        sorted_requests = sorted(appointment_requests, 
                               key=lambda x: self._calculate_priority(x),
                               reverse=True)
        
        for request in sorted_requests:
            best_slot = self._find_best_slot(request, available_slots)
            
            if best_slot:
                optimized_schedule.append({
                    'appointment_id': request['id'],
                    'slot': best_slot,
                    'confidence_score': self._calculate_confidence(request, best_slot)
                })
                
                # Remove assigned slot from available slots
                available_slots.remove(best_slot)
        
        return optimized_schedule
    
    def _calculate_priority(self, request: Dict) -> float:
        """Calculate priority score for appointment request."""
        priority_score = 0
        
        # Urgency factor
        if request.get('reason') == 'emergency':
            priority_score += 100
        elif request.get('reason') == 'urgent':
            priority_score += 50
        elif request.get('reason') == 'follow_up':
            priority_score += 30
        
        # Patient factors
        if request.get('patient_age', 0) > 65:
            priority_score += 20
        
        if request.get('chronic_condition', False):
            priority_score += 15
        
        # Booking time factor (earlier requests get slight priority)
        hours_since_request = (datetime.now() - 
                             pd.to_datetime(request['created_at'])).total_seconds() / 3600
        priority_score += min(hours_since_request * 0.1, 10)
        
        return priority_score
    
    def _find_best_slot(self, request: Dict, available_slots: List[Dict]) -> Dict:
        """Find the best available slot for a request."""
        if not available_slots:
            return None
        
        # Score each available slot
        slot_scores = []
        for slot in available_slots:
            score = self._score_slot(request, slot)
            slot_scores.append((slot, score))
        
        # Return slot with highest score
        best_slot = max(slot_scores, key=lambda x: x[1])[0]
        return best_slot
    
    def _score_slot(self, request: Dict, slot: Dict) -> float:
        """Score how well a slot matches a request."""
        score = 0
        
        # Preferred time match
        preferred_time = request.get('preferred_time')
        if preferred_time:
            slot_time = pd.to_datetime(slot['start_time']).hour
            preferred_hour = pd.to_datetime(preferred_time).hour
            time_diff = abs(slot_time - preferred_hour)
            score += max(10 - time_diff, 0)
        
        # Preferred day match
        preferred_day = request.get('preferred_day')
        if preferred_day:
            slot_day = pd.to_datetime(slot['start_time']).dayofweek
            if slot_day == preferred_day:
                score += 20
        
        # Doctor preference
        preferred_doctor = request.get('preferred_doctor_id')
        if preferred_doctor and slot.get('doctor_id') == preferred_doctor:
            score += 30
        
        return score
```

## Data Processing

### Data Pipeline

```python
# src/pipelines/data_pipeline.py
import pandas as pd
from typing import Dict, List
from datetime import datetime, timedelta

class DataPipeline:
    """Main data processing pipeline."""
    
    def __init__(self, database_connection):
        self.db = database_connection
    
    def extract_patient_data(self, patient_id: str = None, 
                           start_date: datetime = None,
                           end_date: datetime = None) -> pd.DataFrame:
        """Extract patient data from database."""
        query = """
        SELECT 
            u.id as patient_id,
            u.email,
            u.full_name,
            u.created_at,
            EXTRACT(YEAR FROM AGE(u.date_of_birth)) as age,
            u.phone,
            u.is_active
        FROM users u
        WHERE u.role = 'patient'
        """
        
        conditions = []
        params = {}
        
        if patient_id:
            conditions.append("u.id = %(patient_id)s")
            params['patient_id'] = patient_id
        
        if start_date:
            conditions.append("u.created_at >= %(start_date)s")
            params['start_date'] = start_date
        
        if end_date:
            conditions.append("u.created_at <= %(end_date)s")
            params['end_date'] = end_date
        
        if conditions:
            query += " AND " + " AND ".join(conditions)
        
        return pd.read_sql_query(query, self.db, params=params)
    
    def extract_appointment_data(self, start_date: datetime = None,
                               end_date: datetime = None) -> pd.DataFrame:
        """Extract appointment data from database."""
        query = """
        SELECT 
            a.id as appointment_id,
            a.patient_id,
            a.doctor_name,
            a.clinic_name,
            a.appointment_at,
            a.appointment_end_at,
            a.reason,
            a.status,
            a.created_at,
            a.updated_at,
            a.cancelled_at
        FROM appointments a
        """
        
        conditions = []
        params = {}
        
        if start_date:
            conditions.append("a.appointment_at >= %(start_date)s")
            params['start_date'] = start_date
        
        if end_date:
            conditions.append("a.appointment_at <= %(end_date)s")
            params['end_date'] = end_date
        
        if conditions:
            query += " WHERE " + " AND ".join(conditions)
        
        return pd.read_sql_query(query, self.db, params=params)
    
    def extract_environmental_data(self, start_date: datetime = None,
                                 end_date: datetime = None) -> pd.DataFrame:
        """Extract environmental data (would come from external APIs)."""
        # This would integrate with the environmental API
        # For now, return sample data structure
        
        date_range = pd.date_range(
            start=start_date or datetime.now() - timedelta(days=30),
            end=end_date or datetime.now(),
            freq='H'
        )
        
        # Sample environmental data
        data = {
            'timestamp': date_range,
            'aqi': np.random.randint(20, 150, len(date_range)),
            'temperature': np.random.normal(25, 10, len(date_range)),
            'humidity': np.random.randint(30, 90, len(date_range)),
            'location': ['default'] * len(date_range)
        }
        
        return pd.DataFrame(data)
    
    def create_feature_dataset(self) -> pd.DataFrame:
        """Create comprehensive feature dataset for ML models."""
        # Extract all necessary data
        patients = self.extract_patient_data()
        appointments = self.extract_appointment_data()
        environmental = self.extract_environmental_data()
        
        # Merge datasets
        # Patient-appointment merge
        patient_appointments = pd.merge(appointments, patients, 
                                      left_on='patient_id', right_on='patient_id')
        
        # Add environmental data (by date and location)
        patient_appointments['appointment_date'] = pd.to_datetime(
            patient_appointments['appointment_at']).dt.date
        environmental['date'] = pd.to_datetime(environmental['timestamp']).dt.date
        
        # Get daily averages for environmental data
        env_daily = environmental.groupby(['date', 'location']).agg({
            'aqi': 'mean',
            'temperature': 'mean',
            'humidity': 'mean'
        }).reset_index()
        
        # Merge environmental data
        full_dataset = pd.merge(
            patient_appointments, 
            env_daily, 
            left_on='appointment_date', 
            right_on='date',
            how='left'
        )
        
        # Feature engineering
        full_dataset['appointment_hour'] = pd.to_datetime(
            full_dataset['appointment_at']).dt.hour
        full_dataset['appointment_day_of_week'] = pd.to_datetime(
            full_dataset['appointment_at']).dt.dayofweek
        full_dataset['days_between_booking_and_appointment'] = (
            pd.to_datetime(full_dataset['appointment_at']) - 
            pd.to_datetime(full_dataset['created_at'])
        ).dt.days
        
        return full_dataset
```

## Model Evaluation

### Evaluation Framework

```python
# src/evaluation/model_evaluator.py
from sklearn.metrics import accuracy_score, precision_score, recall_score, f1_score
from sklearn.metrics import mean_squared_error, mean_absolute_error, r2_score
from sklearn.model_selection import cross_val_score, StratificationKFold
import matplotlib.pyplot as plt
import seaborn as sns

class ModelEvaluator:
    """Comprehensive model evaluation framework."""
    
    def __init__(self):
        self.results = {}
    
    def evaluate_classification_model(self, model, X_test, y_test, 
                                    model_name: str) -> Dict:
        """Evaluate classification model performance."""
        y_pred = model.predict(X_test)
        y_pred_proba = model.predict_proba(X_test)[:, 1] if hasattr(model, 'predict_proba') else None
        
        metrics = {
            'accuracy': accuracy_score(y_test, y_pred),
            'precision': precision_score(y_test, y_pred, average='weighted'),
            'recall': recall_score(y_test, y_pred, average='weighted'),
            'f1_score': f1_score(y_test, y_pred, average='weighted')
        }
        
        # Cross-validation
        cv_scores = cross_val_score(model, X_test, y_test, cv=5, scoring='accuracy')
        metrics['cv_accuracy_mean'] = cv_scores.mean()
        metrics['cv_accuracy_std'] = cv_scores.std()
        
        self.results[model_name] = metrics
        
        # Generate plots
        self._plot_classification_results(y_test, y_pred, model_name)
        
        return metrics
    
    def evaluate_regression_model(self, model, X_test, y_test, 
                                model_name: str) -> Dict:
        """Evaluate regression model performance."""
        y_pred = model.predict(X_test)
        
        metrics = {
            'mse': mean_squared_error(y_test, y_pred),
            'mae': mean_absolute_error(y_test, y_pred),
            'r2_score': r2_score(y_test, y_pred),
            'rmse': np.sqrt(mean_squared_error(y_test, y_pred))
        }
        
        self.results[model_name] = metrics
        
        # Generate plots
        self._plot_regression_results(y_test, y_pred, model_name)
        
        return metrics
    
    def _plot_classification_results(self, y_true, y_pred, model_name: str):
        """Plot classification results."""
        fig, axes = plt.subplots(1, 2, figsize=(12, 5))
        
        # Confusion Matrix
        from sklearn.metrics import confusion_matrix
        cm = confusion_matrix(y_true, y_pred)
        sns.heatmap(cm, annot=True, fmt='d', ax=axes[0])
        axes[0].set_title(f'{model_name} - Confusion Matrix')
        
        # Feature Importance (if available)
        if hasattr(model, 'feature_importances_'):
            feature_importance = pd.DataFrame({
                'feature': range(len(model.feature_importances_)),
                'importance': model.feature_importances_
            }).sort_values('importance', ascending=False).head(10)
            
            axes[1].barh(feature_importance['feature'], feature_importance['importance'])
            axes[1].set_title(f'{model_name} - Feature Importance')
        
        plt.tight_layout()
        plt.savefig(f'results/{model_name}_classification_results.png')
        plt.close()
    
    def _plot_regression_results(self, y_true, y_pred, model_name: str):
        """Plot regression results."""
        fig, axes = plt.subplots(1, 2, figsize=(12, 5))
        
        # Actual vs Predicted
        axes[0].scatter(y_true, y_pred, alpha=0.5)
        axes[0].plot([y_true.min(), y_true.max()], [y_true.min(), y_true.max()], 'r--', lw=2)
        axes[0].set_xlabel('Actual')
        axes[0].set_ylabel('Predicted')
        axes[0].set_title(f'{model_name} - Actual vs Predicted')
        
        # Residuals
        residuals = y_true - y_pred
        axes[1].scatter(y_pred, residuals, alpha=0.5)
        axes[1].axhline(y=0, color='r', linestyle='--')
        axes[1].set_xlabel('Predicted')
        axes[1].set_ylabel('Residuals')
        axes[1].set_title(f'{model_name} - Residual Plot')
        
        plt.tight_layout()
        plt.savefig(f'results/{model_name}_regression_results.png')
        plt.close()
    
    def compare_models(self) -> pd.DataFrame:
        """Compare performance across all evaluated models."""
        if not self.results:
            print("No models evaluated yet.")
            return pd.DataFrame()
        
        comparison_df = pd.DataFrame(self.results).T
        
        # Plot comparison
        plt.figure(figsize=(12, 8))
        comparison_df.plot(kind='bar', ax=plt.gca())
        plt.title('Model Performance Comparison')
        plt.xticks(rotation=45)
        plt.tight_layout()
        plt.savefig('results/model_comparison.png')
        plt.close()
        
        return comparison_df
```

## Deployment

### Model Serving API

```python
# src/deployment/model_api.py
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
import joblib
import pandas as pd
from typing import Dict, List

app = FastAPI(title="Medico24 ML API", version="1.0.0")

# Load trained models
health_risk_model = joblib.load('models/health_risk_model.pkl')
environmental_model = joblib.load('models/environmental_model.pkl')

class HealthRiskRequest(BaseModel):
    age: int
    bmi: float
    blood_pressure_systolic: int
    blood_pressure_diastolic: int
    cholesterol: int
    glucose: float
    smoking: bool
    physical_activity: int
    family_history: bool
    environmental_exposure: float

class EnvironmentalRiskRequest(BaseModel):
    aqi: int
    temperature: float
    humidity: float
    location: str

@app.post("/predict/health-risk")
async def predict_health_risk(request: HealthRiskRequest) -> Dict:
    """Predict health risk based on patient data."""
    try:
        patient_data = request.dict()
        prediction = health_risk_model.predict_risk(patient_data)
        return prediction
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/predict/environmental-risk")
async def predict_environmental_risk(request: EnvironmentalRiskRequest) -> Dict:
    """Predict health risk from environmental conditions."""
    try:
        env_data = request.dict()
        prediction = environmental_model.predict_health_risk_from_environment(env_data)
        return prediction
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/health")
async def health_check():
    """Health check endpoint."""
    return {"status": "healthy", "service": "ml-api"}

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8001)
```

## Testing

### Model Tests

```python
# tests/test_health_risk_model.py
import pytest
import pandas as pd
import numpy as np
from src.models.health_risk_model import HealthRiskModel

def test_health_risk_model_initialization():
    """Test model initialization."""
    model = HealthRiskModel()
    assert model.model is not None
    assert model.scaler is not None
    assert len(model.features) > 0

def test_health_risk_prediction():
    """Test health risk prediction."""
    model = HealthRiskModel()
    
    # Sample patient data
    patient_data = {
        'age': 45,
        'bmi': 28.5,
        'blood_pressure_systolic': 140,
        'blood_pressure_diastolic': 90,
        'cholesterol': 220,
        'glucose': 110,
        'smoking': True,
        'physical_activity': 2,
        'family_history': True,
        'environmental_exposure': 0.7
    }
    
    # Mock training data
    X_train = pd.DataFrame([
        patient_data,
        {k: v * 0.8 if isinstance(v, (int, float)) else False 
         for k, v in patient_data.items()}
    ])
    y_train = pd.Series([1, 0])  # High risk, Low risk
    
    # Train model
    model.train(X_train, y_train)
    
    # Test prediction
    prediction = model.predict_risk(patient_data)
    
    assert 'risk_level' in prediction
    assert 'risk_probability' in prediction
    assert 'recommendations' in prediction
    assert isinstance(prediction['recommendations'], list)

def test_model_preprocessing():
    """Test data preprocessing."""
    model = HealthRiskModel()
    
    # Test data with missing values
    data = pd.DataFrame({
        'age': [25, 45, np.nan, 65],
        'bmi': [22, np.nan, 30, 28],
        'cholesterol': [180, 220, 250, np.nan]
    })
    
    processed = model.preprocess(data)
    
    # Check that missing values are handled
    assert not processed.isnull().any().any()
    
    # Check that new features are created
    assert 'bmi_category' in processed.columns
    assert 'age_group' in processed.columns
```

## Monitoring and Maintenance

### Model Monitoring

```python
# src/monitoring/model_monitor.py
import mlflow
import pandas as pd
from datetime import datetime, timedelta
from typing import Dict, List

class ModelMonitor:
    """Monitor model performance and data drift."""
    
    def __init__(self, model_name: str):
        self.model_name = model_name
        mlflow.set_tracking_uri("http://localhost:5000")
    
    def log_prediction(self, input_data: Dict, prediction: Dict, 
                      actual_outcome: str = None):
        """Log model prediction for monitoring."""
        with mlflow.start_run():
            # Log input features
            for key, value in input_data.items():
                mlflow.log_param(f"input_{key}", value)
            
            # Log prediction
            mlflow.log_metric("prediction_confidence", 
                            prediction.get('confidence', 0))
            mlflow.log_param("prediction_result", 
                           prediction.get('risk_level', 'unknown'))
            
            # Log actual outcome if available
            if actual_outcome:
                mlflow.log_param("actual_outcome", actual_outcome)
    
    def check_data_drift(self, current_data: pd.DataFrame, 
                        reference_data: pd.DataFrame) -> Dict:
        """Check for data drift in input features."""
        drift_results = {}
        
        for column in current_data.columns:
            if column in reference_data.columns:
                # Statistical tests for drift detection
                from scipy import stats
                
                if current_data[column].dtype in ['float64', 'int64']:
                    # Kolmogorov-Smirnov test for numerical features
                    statistic, p_value = stats.ks_2samp(
                        reference_data[column].dropna(),
                        current_data[column].dropna()
                    )
                    
                    drift_results[column] = {
                        'test': 'ks_test',
                        'statistic': statistic,
                        'p_value': p_value,
                        'drift_detected': p_value < 0.05
                    }
                
                else:
                    # Chi-square test for categorical features
                    ref_counts = reference_data[column].value_counts(normalize=True)
                    curr_counts = current_data[column].value_counts(normalize=True)
                    
                    # Align indices
                    all_categories = set(ref_counts.index) | set(curr_counts.index)
                    ref_aligned = ref_counts.reindex(all_categories, fill_value=0)
                    curr_aligned = curr_counts.reindex(all_categories, fill_value=0)
                    
                    if len(all_categories) > 1:
                        statistic, p_value = stats.chisquare(
                            curr_aligned * len(current_data),
                            ref_aligned * len(reference_data)
                        )
                        
                        drift_results[column] = {
                            'test': 'chi_square',
                            'statistic': statistic,
                            'p_value': p_value,
                            'drift_detected': p_value < 0.05
                        }
        
        return drift_results
    
    def generate_performance_report(self) -> Dict:
        """Generate model performance report."""
        # This would query MLflow for recent predictions and actual outcomes
        # and calculate performance metrics
        
        # Placeholder for report structure
        report = {
            'model_name': self.model_name,
            'evaluation_period': {
                'start': datetime.now() - timedelta(days=7),
                'end': datetime.now()
            },
            'metrics': {
                'accuracy': 0.0,
                'precision': 0.0,
                'recall': 0.0,
                'f1_score': 0.0
            },
            'data_drift': {},
            'recommendations': []
        }
        
        return report
```

## Usage Examples

### Training a Model

```python
# scripts/train_health_risk_model.py
from src.models.health_risk_model import HealthRiskModel
from src.pipelines.data_pipeline import DataPipeline
from src.evaluation.model_evaluator import ModelEvaluator
import joblib

def main():
    # Initialize components
    pipeline = DataPipeline(database_connection)
    model = HealthRiskModel()
    evaluator = ModelEvaluator()
    
    # Create dataset
    dataset = pipeline.create_feature_dataset()
    
    # Prepare features and target
    features = model.features
    X = dataset[features]
    y = dataset['health_risk_level']  # This would be derived from outcomes
    
    # Split data
    from sklearn.model_selection import train_test_split
    X_train, X_test, y_train, y_test = train_test_split(
        X, y, test_size=0.2, random_state=42, stratify=y
    )
    
    # Train model
    model.train(X_train, y_train)
    
    # Evaluate model
    metrics = evaluator.evaluate_classification_model(
        model, X_test, y_test, 'HealthRiskModel'
    )
    
    print(f"Model Performance: {metrics}")
    
    # Save model
    joblib.dump(model, 'models/health_risk_model.pkl')
    print("Model saved successfully!")

if __name__ == "__main__":
    main()
```

### Making Predictions

```python
# Example usage in application
from src.models.health_risk_model import HealthRiskModel
import joblib

# Load trained model
model = joblib.load('models/health_risk_model.pkl')

# Patient data
patient_data = {
    'age': 45,
    'bmi': 28.5,
    'blood_pressure_systolic': 140,
    'blood_pressure_diastolic': 90,
    'cholesterol': 220,
    'glucose': 110,
    'smoking': True,
    'physical_activity': 2,
    'family_history': True,
    'environmental_exposure': 0.7
}

# Get prediction
prediction = model.predict_risk(patient_data)

print(f"Risk Level: {prediction['risk_level']}")
print(f"Risk Probabilities: {prediction['risk_probability']}")
print(f"Recommendations: {prediction['recommendations']}")
```

## Future Enhancements

### Planned Features

1. **Deep Learning Models** - Neural networks for complex pattern recognition
2. **Real-time Predictions** - Streaming ML pipeline for real-time risk assessment
3. **Federated Learning** - Privacy-preserving ML across healthcare institutions
4. **Automated ML** - AutoML pipeline for model selection and hyperparameter tuning
5. **Explainable AI** - SHAP/LIME integration for model interpretability
6. **Time Series Forecasting** - Predict health trends over time
7. **Computer Vision** - Medical image analysis capabilities
8. **Natural Language Processing** - Analysis of clinical notes and patient feedback

## Best Practices

### Data Handling
- Always validate input data quality
- Implement proper data versioning
- Ensure patient data privacy (HIPAA compliance)
- Use proper data splitting (temporal for time series)
- Handle missing data appropriately

### Model Development
- Start with simple baseline models
- Use cross-validation for model selection
- Implement proper feature engineering
- Document all modeling decisions
- Version control models and experiments

### Deployment
- Test models thoroughly before deployment
- Implement proper monitoring and alerting
- Use A/B testing for model updates
- Maintain model rollback capabilities
- Monitor for data drift and model decay

## Related Documentation

- [API Documentation](../api/overview.md) - Backend API integration
- [System Architecture](../architecture/overview.md) - Overall system design
- [Development Guide](development.md) - Development setup
- [Data Privacy Guide](data-privacy.md) - HIPAA compliance and data handling