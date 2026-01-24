# Testing Guide

## Overview

This guide covers testing strategies and procedures for all components of the Medico24 platform.

## Testing Strategy

### Testing Pyramid

1. **Unit Tests** (70%)
   - Individual function/method testing
   - Fast execution
   - High coverage

2. **Integration Tests** (20%)
   - Component interaction testing
   - API endpoint testing
   - Database integration

3. **End-to-End Tests** (10%)
   - Full user workflow testing
   - Cross-platform testing
   - Performance testing

## Backend Testing

### Unit Testing

#### Setup

```bash
cd medico24-backend
pip install pytest pytest-cov pytest-asyncio
```

#### Running Tests

```bash
# Run all tests
pytest

# Run with coverage
pytest --cov=app

# Run specific test file
pytest tests/test_auth.py

# Run with verbose output
pytest -v
```

#### Example Unit Test

```python
# tests/test_auth.py
import pytest
from app.auth import create_access_token, verify_token

def test_create_access_token():
    """Test JWT token creation."""
    user_data = {"user_id": "123", "email": "test@example.com"}
    token = create_access_token(user_data)
    assert token is not None
    assert isinstance(token, str)

def test_verify_token():
    """Test JWT token verification."""
    user_data = {"user_id": "123", "email": "test@example.com"}
    token = create_access_token(user_data)
    decoded = verify_token(token)
    assert decoded["user_id"] == "123"
    assert decoded["email"] == "test@example.com"
```

### Integration Testing

#### API Testing

```python
# tests/test_api.py
import pytest
from fastapi.testclient import TestClient
from app.main import app

client = TestClient(app)

def test_register_user():
    """Test user registration endpoint."""
    response = client.post(
        "/auth/register",
        json={
            "email": "test@example.com",
            "password": "password123",
            "full_name": "Test User"
        }
    )
    assert response.status_code == 201
    data = response.json()
    assert data["email"] == "test@example.com"
    assert "id" in data

def test_login_user():
    """Test user login endpoint."""
    # First register a user
    client.post("/auth/register", json={
        "email": "login@example.com",
        "password": "password123",
        "full_name": "Login User"
    })
    
    # Then test login
    response = client.post(
        "/auth/login",
        json={
            "email": "login@example.com",
            "password": "password123"
        }
    )
    assert response.status_code == 200
    data = response.json()
    assert "access_token" in data
    assert data["token_type"] == "bearer"
```

### Database Testing

```python
# tests/test_database.py
import pytest
from app.database import get_db
from app.models import User

@pytest.fixture
def db_session():
    """Create a test database session."""
    # Setup test database
    db = next(get_db())
    yield db
    # Cleanup
    db.rollback()

def test_create_user(db_session):
    """Test user creation in database."""
    user = User(
        email="db@example.com",
        hashed_password="hashed_pwd",
        full_name="DB User"
    )
    db_session.add(user)
    db_session.commit()
    
    # Verify user was created
    created_user = db_session.query(User).filter(
        User.email == "db@example.com"
    ).first()
    assert created_user is not None
    assert created_user.full_name == "DB User"
```

## Mobile App Testing

### Unit Testing

#### Setup

```yaml
# pubspec.yaml
dev_dependencies:
  flutter_test:
    sdk: flutter
  mockito: ^5.3.0
  build_runner: ^2.2.0
```

#### Running Tests

```bash
# Run all tests
flutter test

# Run with coverage
flutter test --coverage

# Run specific test file
flutter test test/auth_test.dart
```

#### Example Unit Test

```dart
// test/auth_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:medico24/services/auth_service.dart';

class MockHttpClient extends Mock implements HttpClient {}

void main() {
  group('AuthService', () {
    late AuthService authService;
    late MockHttpClient mockHttpClient;

    setUp(() {
      mockHttpClient = MockHttpClient();
      authService = AuthService(httpClient: mockHttpClient);
    });

    test('should login successfully with valid credentials', () async {
      // Arrange
      when(mockHttpClient.post(any, body: any))
          .thenAnswer((_) async => MockResponse(200, '{"token": "abc123"}'));

      // Act
      final result = await authService.login('test@example.com', 'password');

      // Assert
      expect(result.isSuccess, true);
      expect(result.token, 'abc123');
    });

    test('should return error for invalid credentials', () async {
      // Arrange
      when(mockHttpClient.post(any, body: any))
          .thenAnswer((_) async => MockResponse(401, '{"error": "Invalid credentials"}'));

      // Act
      final result = await authService.login('test@example.com', 'wrongpassword');

      // Assert
      expect(result.isSuccess, false);
      expect(result.error, 'Invalid credentials');
    });
  });
}
```

### Widget Testing

```dart
// test/widget_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medico24/screens/login_screen.dart';

void main() {
  group('LoginScreen', () {
    testWidgets('should display login form', (WidgetTester tester) async {
      // Arrange & Act
      await tester.pumpWidget(MaterialApp(home: LoginScreen()));

      // Assert
      expect(find.text('Email'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
      expect(find.text('Login'), findsOneWidget);
      expect(find.byType(TextFormField), findsNWidgets(2));
      expect(find.byType(ElevatedButton), findsOneWidget);
    });

    testWidgets('should validate email field', (WidgetTester tester) async {
      // Arrange
      await tester.pumpWidget(MaterialApp(home: LoginScreen()));

      // Act
      await tester.tap(find.text('Login'));
      await tester.pump();

      // Assert
      expect(find.text('Please enter your email'), findsOneWidget);
    });
  });
}
```

### Integration Testing

```dart
// integration_test/app_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:medico24/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('App Integration Tests', () {
    testWidgets('complete user flow', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle();

      // Test login flow
      await tester.enterText(find.byKey(Key('email_field')), 'test@example.com');
      await tester.enterText(find.byKey(Key('password_field')), 'password123');
      await tester.tap(find.byKey(Key('login_button')));
      await tester.pumpAndSettle();

      // Verify navigation to dashboard
      expect(find.text('Dashboard'), findsOneWidget);
    });
  });
}
```

## Web Dashboard Testing

### Unit Testing

#### Setup

```bash
cd medico24-website
npm install --save-dev jest @testing-library/react @testing-library/jest-dom
```

#### Running Tests

```bash
# Run all tests
npm test

# Run with coverage
npm test -- --coverage

# Run in watch mode
npm test -- --watch
```

#### Example Component Test

```javascript
// components/__tests__/LoginForm.test.tsx
import { render, screen, fireEvent, waitFor } from '@testing-library/react';
import { LoginForm } from '../LoginForm';

describe('LoginForm', () => {
  test('renders login form elements', () => {
    render(<LoginForm onSubmit={jest.fn()} />);
    
    expect(screen.getByLabelText(/email/i)).toBeInTheDocument();
    expect(screen.getByLabelText(/password/i)).toBeInTheDocument();
    expect(screen.getByRole('button', { name: /login/i })).toBeInTheDocument();
  });

  test('validates required fields', async () => {
    const onSubmit = jest.fn();
    render(<LoginForm onSubmit={onSubmit} />);
    
    fireEvent.click(screen.getByRole('button', { name: /login/i }));
    
    await waitFor(() => {
      expect(screen.getByText(/email is required/i)).toBeInTheDocument();
      expect(screen.getByText(/password is required/i)).toBeInTheDocument();
    });
    
    expect(onSubmit).not.toHaveBeenCalled();
  });

  test('submits form with valid data', async () => {
    const onSubmit = jest.fn();
    render(<LoginForm onSubmit={onSubmit} />);
    
    fireEvent.change(screen.getByLabelText(/email/i), {
      target: { value: 'test@example.com' }
    });
    fireEvent.change(screen.getByLabelText(/password/i), {
      target: { value: 'password123' }
    });
    
    fireEvent.click(screen.getByRole('button', { name: /login/i }));
    
    await waitFor(() => {
      expect(onSubmit).toHaveBeenCalledWith({
        email: 'test@example.com',
        password: 'password123'
      });
    });
  });
});
```

### API Testing

```javascript
// lib/__tests__/api.test.ts
import { authApi } from '../api';

// Mock fetch
global.fetch = jest.fn();

describe('authApi', () => {
  beforeEach(() => {
    fetch.mockClear();
  });

  test('login returns token on success', async () => {
    fetch.mockResolvedValueOnce({
      ok: true,
      json: async () => ({ token: 'abc123', user: { id: '1' } })
    });

    const result = await authApi.login('test@example.com', 'password');
    
    expect(result.token).toBe('abc123');
    expect(result.user.id).toBe('1');
    expect(fetch).toHaveBeenCalledWith('/api/auth/login', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        email: 'test@example.com',
        password: 'password'
      })
    });
  });
});
```

## ML Module Testing

### Model Testing

```python
# tests/test_models.py
import pytest
import numpy as np
from src.models.health_predictor import HealthPredictor

def test_health_predictor():
    """Test health prediction model."""
    model = HealthPredictor()
    
    # Sample input data
    features = np.array([[25, 70, 170, 80, 120]])  # age, weight, height, hr, bp
    
    prediction = model.predict(features)
    
    assert prediction is not None
    assert 0 <= prediction[0] <= 1  # Probability between 0 and 1

def test_model_validation():
    """Test model input validation."""
    model = HealthPredictor()
    
    # Invalid input (negative values)
    with pytest.raises(ValueError):
        model.predict(np.array([[-1, 70, 170, 80, 120]]))
```

### Data Testing

```python
# tests/test_data.py
import pytest
import pandas as pd
from src.data.preprocessor import DataPreprocessor

def test_data_preprocessing():
    """Test data preprocessing pipeline."""
    # Sample data
    data = pd.DataFrame({
        'age': [25, 30, 35],
        'weight': [70, 80, 90],
        'height': [170, 180, 175],
        'missing_col': [None, 'value', None]
    })
    
    preprocessor = DataPreprocessor()
    processed = preprocessor.transform(data)
    
    # Check that missing values are handled
    assert not processed.isnull().any().any()
    
    # Check data types
    assert processed['age'].dtype in ['int64', 'float64']
```

## End-to-End Testing

### Setup with Playwright

```bash
npm install --save-dev @playwright/test
npx playwright install
```

### E2E Test Example

```javascript
// e2e/auth.spec.ts
import { test, expect } from '@playwright/test';

test.describe('Authentication Flow', () => {
  test('user can register and login', async ({ page }) => {
    // Navigate to app
    await page.goto('/');
    
    // Register new user
    await page.click('text=Register');
    await page.fill('[data-testid=email]', 'e2e@example.com');
    await page.fill('[data-testid=password]', 'password123');
    await page.fill('[data-testid=confirm-password]', 'password123');
    await page.click('[data-testid=register-button]');
    
    // Should redirect to dashboard
    await expect(page).toHaveURL('/dashboard');
    await expect(page.locator('h1')).toContainText('Dashboard');
    
    // Logout
    await page.click('[data-testid=logout-button]');
    
    // Login with same credentials
    await page.fill('[data-testid=email]', 'e2e@example.com');
    await page.fill('[data-testid=password]', 'password123');
    await page.click('[data-testid=login-button]');
    
    // Should be back on dashboard
    await expect(page).toHaveURL('/dashboard');
  });
});
```

## Performance Testing

### Load Testing with Artillery

```yaml
# load-test.yml
config:
  target: 'http://localhost:8000'
  phases:
    - duration: 60
      arrivalRate: 10
scenarios:
  - name: "API Health Check"
    requests:
      - get:
          url: "/health"
  - name: "User Registration"
    requests:
      - post:
          url: "/auth/register"
          json:
            email: "load{{ $randomString() }}@example.com"
            password: "password123"
            full_name: "Load Test User"
```

Run load test:
```bash
artillery run load-test.yml
```

## Test Data Management

### Database Fixtures

```python
# tests/fixtures.py
import pytest
from app.database import get_db
from app.models import User, Appointment

@pytest.fixture
def sample_user():
    """Create a sample user for testing."""
    return User(
        email="fixture@example.com",
        hashed_password="hashed_password",
        full_name="Fixture User",
        is_active=True
    )

@pytest.fixture
def sample_appointment(sample_user):
    """Create a sample appointment for testing."""
    return Appointment(
        user_id=sample_user.id,
        doctor_name="Dr. Test",
        appointment_date="2023-12-01T10:00:00",
        status="scheduled"
    )
```

### Test Data Cleanup

```python
# conftest.py
import pytest
from app.database import SessionLocal, engine
from app.models import Base

@pytest.fixture(scope="session", autouse=True)
def setup_test_db():
    """Setup test database."""
    Base.metadata.create_all(bind=engine)
    yield
    Base.metadata.drop_all(bind=engine)

@pytest.fixture
def db():
    """Provide database session for tests."""
    connection = engine.connect()
    transaction = connection.begin()
    session = SessionLocal(bind=connection)
    
    yield session
    
    session.close()
    transaction.rollback()
    connection.close()
```

## Continuous Integration

### GitHub Actions Workflow

```yaml
name: Tests

on: [push, pull_request]

jobs:
  backend-tests:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - name: Set up Python
        uses: actions/setup-python@v2
        with:
          python-version: 3.9
      - name: Install dependencies
        run: |
          pip install -r requirements.txt
          pip install pytest pytest-cov
      - name: Run tests
        run: pytest --cov=app --cov-report=xml
      - name: Upload coverage
        uses: codecov/codecov-action@v1

  frontend-tests:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - name: Set up Node.js
        uses: actions/setup-node@v2
        with:
          node-version: '18'
      - name: Install dependencies
        run: npm install
      - name: Run tests
        run: npm test -- --coverage --watchAll=false

  mobile-tests:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - name: Set up Flutter
        uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.0.0'
      - name: Run tests
        run: flutter test
```

## Test Coverage

### Coverage Goals

- Backend: 80% minimum
- Frontend: 70% minimum
- Mobile: 70% minimum
- Integration: 60% minimum

### Coverage Reports

```bash
# Backend coverage
pytest --cov=app --cov-report=html

# Frontend coverage
npm test -- --coverage

# Mobile coverage
flutter test --coverage
genhtml coverage/lcov.info -o coverage/html
```

## Best Practices

### Test Organization

1. **Arrange-Act-Assert Pattern:**
   ```python
   def test_function():
       # Arrange
       input_data = "test"
       
       # Act
       result = function_under_test(input_data)
       
       # Assert
       assert result == expected_result
   ```

2. **Test Naming Convention:**
   - `test_[function]_[scenario]_[expected_result]`
   - Example: `test_login_valid_credentials_returns_token`

3. **Independent Tests:**
   - Each test should be independent
   - Use fixtures for setup/teardown
   - Clean up after tests

### Mock Strategies

```python
# External service mocking
@patch('app.services.email_service.send_email')
def test_user_registration_sends_email(mock_send_email):
    mock_send_email.return_value = True
    # Test implementation
    assert mock_send_email.called
```

## Resources

- [Pytest Documentation](https://docs.pytest.org/)
- [Flutter Testing](https://flutter.dev/docs/testing)
- [React Testing Library](https://testing-library.com/docs/react-testing-library/intro/)
- [Playwright Documentation](https://playwright.dev/)
- [Artillery Load Testing](https://artillery.io/docs/)