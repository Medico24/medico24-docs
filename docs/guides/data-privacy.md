# Data Privacy Guide

## Overview

This guide outlines data privacy and protection measures implemented across the Medico24 platform to ensure compliance with healthcare data regulations and protect user privacy.

## Regulatory Compliance

### HIPAA Compliance

The Medico24 platform implements comprehensive HIPAA (Health Insurance Portability and Accountability Act) compliance measures:

#### Administrative Safeguards

1. **Security Officer:** Designated security officer responsible for HIPAA compliance
2. **Access Management:** Formal access control procedures and user authentication
3. **Workforce Training:** Regular training on HIPAA requirements and data handling
4. **Incident Response:** Documented procedures for security incidents and breaches
5. **Business Associate Agreements:** Contracts with third-party vendors

#### Physical Safeguards

1. **Facility Access:** Secure data centers with controlled physical access
2. **Workstation Security:** Secure workstation configurations and monitoring
3. **Device Controls:** Management of devices that access or store PHI
4. **Media Disposal:** Secure disposal and reuse of electronic media

#### Technical Safeguards

1. **Access Control:** Unique user identification and authentication
2. **Audit Controls:** Comprehensive logging and monitoring
3. **Integrity Controls:** Data integrity verification and protection
4. **Transmission Security:** Encryption for data in transit

### GDPR Compliance

For users in the European Union, the platform implements GDPR (General Data Protection Regulation) compliance:

#### Data Protection Principles

1. **Lawfulness:** Clear legal basis for data processing
2. **Purpose Limitation:** Data used only for specified purposes
3. **Data Minimization:** Collect only necessary data
4. **Accuracy:** Maintain accurate and up-to-date data
5. **Storage Limitation:** Retain data only as long as necessary
6. **Integrity and Confidentiality:** Ensure data security

#### User Rights

1. **Right to Access:** Users can request access to their data
2. **Right to Rectification:** Users can correct inaccurate data
3. **Right to Erasure:** Users can request data deletion
4. **Right to Portability:** Users can export their data
5. **Right to Object:** Users can object to data processing

## Data Classification and Handling

### Data Classification Levels

```python
# app/models/data_classification.py
from enum import Enum

class DataClassification(Enum):
    PUBLIC = "public"           # Non-sensitive, publicly available
    INTERNAL = "internal"       # Internal business data
    CONFIDENTIAL = "confidential"  # Sensitive business data
    RESTRICTED = "restricted"   # Highly sensitive data (PHI/PII)

class DataType(Enum):
    PHI = "phi"                # Protected Health Information
    PII = "pii"                # Personally Identifiable Information
    FINANCIAL = "financial"    # Financial information
    BIOMETRIC = "biometric"    # Biometric data
    BEHAVIORAL = "behavioral"  # Behavioral/usage data

# Data handling rules
DATA_HANDLING_RULES = {
    DataClassification.RESTRICTED: {
        "encryption_required": True,
        "access_logging": True,
        "retention_period": 7 * 365,  # 7 years
        "anonymization_required": True,
        "consent_required": True,
        "audit_frequency": "monthly"
    },
    DataClassification.CONFIDENTIAL: {
        "encryption_required": True,
        "access_logging": True,
        "retention_period": 5 * 365,  # 5 years
        "anonymization_required": False,
        "consent_required": True,
        "audit_frequency": "quarterly"
    },
    DataClassification.INTERNAL: {
        "encryption_required": False,
        "access_logging": True,
        "retention_period": 3 * 365,  # 3 years
        "anonymization_required": False,
        "consent_required": False,
        "audit_frequency": "annually"
    }
}
```

### Data Model Implementation

```python
# app/models/privacy_models.py
from sqlalchemy import Column, String, DateTime, Boolean, Text, Enum
from sqlalchemy.dialects.postgresql import UUID
import uuid

class DataProcessingRecord(Base):
    """Record of data processing activities."""
    __tablename__ = "data_processing_records"
    
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id = Column(UUID(as_uuid=True), ForeignKey("users.id"))
    data_type = Column(Enum(DataType))
    classification = Column(Enum(DataClassification))
    purpose = Column(String)
    legal_basis = Column(String)
    processing_date = Column(DateTime)
    retention_until = Column(DateTime)
    consent_given = Column(Boolean)
    consent_date = Column(DateTime)
    
class DataAccessLog(Base):
    """Log of data access events."""
    __tablename__ = "data_access_logs"
    
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id = Column(UUID(as_uuid=True))
    accessor_id = Column(UUID(as_uuid=True))
    data_type = Column(Enum(DataType))
    access_type = Column(String)  # read, write, delete, export
    timestamp = Column(DateTime)
    ip_address = Column(String)
    user_agent = Column(String)
    purpose = Column(String)
    
class ConsentRecord(Base):
    """Record of user consent."""
    __tablename__ = "consent_records"
    
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id = Column(UUID(as_uuid=True), ForeignKey("users.id"))
    consent_type = Column(String)  # data_processing, marketing, analytics
    granted = Column(Boolean)
    consent_date = Column(DateTime)
    withdrawn_date = Column(DateTime, nullable=True)
    consent_text = Column(Text)
    version = Column(String)
```

## Data Encryption

### Encryption at Rest

```python
# app/security/encryption.py
from cryptography.fernet import Fernet
from cryptography.hazmat.primitives import hashes
from cryptography.hazmat.primitives.kdf.pbkdf2 import PBKDF2HMAC
import base64
import os

class DataEncryption:
    def __init__(self, password: str = None):
        self.password = password or os.getenv("ENCRYPTION_KEY")
        self._fernet = self._create_fernet()
    
    def _create_fernet(self) -> Fernet:
        """Create Fernet instance for encryption."""
        password = self.password.encode()
        salt = os.getenv("ENCRYPTION_SALT", "medico24_salt").encode()
        
        kdf = PBKDF2HMAC(
            algorithm=hashes.SHA256(),
            length=32,
            salt=salt,
            iterations=100000,
        )
        
        key = base64.urlsafe_b64encode(kdf.derive(password))
        return Fernet(key)
    
    def encrypt(self, data: str) -> str:
        """Encrypt sensitive data."""
        if not data:
            return data
        
        encrypted_data = self._fernet.encrypt(data.encode())
        return base64.urlsafe_b64encode(encrypted_data).decode()
    
    def decrypt(self, encrypted_data: str) -> str:
        """Decrypt sensitive data."""
        if not encrypted_data:
            return encrypted_data
        
        try:
            decoded_data = base64.urlsafe_b64decode(encrypted_data.encode())
            decrypted_data = self._fernet.decrypt(decoded_data)
            return decrypted_data.decode()
        except Exception:
            # Return original data if decryption fails (backwards compatibility)
            return encrypted_data

# SQLAlchemy encrypted field type
from sqlalchemy_utils import EncryptedType
from sqlalchemy_utils.types.encrypted.encrypted_type import AesEngine

class EncryptedString(EncryptedType):
    """Custom encrypted string type for SQLAlchemy."""
    
    def __init__(self, *args, **kwargs):
        kwargs['secret_key'] = os.getenv("DATABASE_ENCRYPTION_KEY")
        kwargs['engine'] = AesEngine
        super().__init__(String, *args, **kwargs)

# Usage in models
class User(Base):
    __tablename__ = "users"
    
    id = Column(UUID(as_uuid=True), primary_key=True)
    email = Column(String, unique=True, index=True)
    
    # Encrypted sensitive fields
    full_name = Column(EncryptedString)
    phone_number = Column(EncryptedString)
    date_of_birth = Column(EncryptedString)
    medical_record_number = Column(EncryptedString)
```

### Encryption in Transit

```python
# app/security/tls_config.py
import ssl
from typing import Dict, Any

def get_tls_config() -> Dict[str, Any]:
    """Get TLS configuration for secure communication."""
    
    # Minimum TLS version
    min_version = ssl.TLSVersion.TLSv1_2
    
    # Cipher suites (secure ones only)
    secure_ciphers = [
        'ECDHE-RSA-AES256-GCM-SHA384',
        'ECDHE-RSA-AES128-GCM-SHA256',
        'ECDHE-RSA-AES256-SHA384',
        'ECDHE-RSA-AES128-SHA256'
    ]
    
    return {
        "ssl_context": ssl.create_default_context(ssl.Purpose.SERVER_AUTH),
        "min_version": min_version,
        "ciphers": ":".join(secure_ciphers),
        "check_hostname": True,
        "verify_mode": ssl.CERT_REQUIRED
    }

# HTTP client with TLS verification
import httpx

class SecureHTTPClient:
    def __init__(self):
        tls_config = get_tls_config()
        self.client = httpx.AsyncClient(
            verify=tls_config["ssl_context"],
            timeout=30.0
        )
    
    async def make_secure_request(self, method: str, url: str, **kwargs):
        """Make HTTPS request with strict TLS verification."""
        if not url.startswith('https://'):
            raise ValueError("Only HTTPS URLs are allowed")
        
        response = await self.client.request(method, url, **kwargs)
        response.raise_for_status()
        return response
```

## Data Anonymization and Pseudonymization

### Anonymization Techniques

```python
# app/privacy/anonymization.py
import hashlib
import random
import string
from typing import Dict, Any, Optional
import re

class DataAnonymizer:
    """Data anonymization utility."""
    
    def __init__(self, salt: str = None):
        self.salt = salt or os.getenv("ANONYMIZATION_SALT", "medico24_anon")
    
    def anonymize_email(self, email: str) -> str:
        """Anonymize email address."""
        if not email or '@' not in email:
            return "anonymous@example.com"
        
        local, domain = email.split('@', 1)
        
        # Keep first character and length
        anonymized_local = local[0] + '*' * (len(local) - 1)
        
        # Anonymize domain but keep structure
        domain_parts = domain.split('.')
        if len(domain_parts) > 1:
            anonymized_domain = '*' * len(domain_parts[0]) + '.' + domain_parts[-1]
        else:
            anonymized_domain = '*' * len(domain)
        
        return f"{anonymized_local}@{anonymized_domain}"
    
    def anonymize_phone(self, phone: str) -> str:
        """Anonymize phone number."""
        if not phone:
            return "***-***-****"
        
        # Remove non-digits
        digits = re.sub(r'\D', '', phone)
        
        if len(digits) >= 10:
            # Keep country code and last 2 digits
            return f"+**-***-***-**{digits[-2:]}"
        else:
            return "***-***-****"
    
    def anonymize_name(self, name: str) -> str:
        """Anonymize name while preserving structure."""
        if not name:
            return "Anonymous User"
        
        parts = name.split()
        anonymized_parts = []
        
        for part in parts:
            if len(part) > 0:
                anonymized_parts.append(part[0] + '*' * (len(part) - 1))
        
        return ' '.join(anonymized_parts)
    
    def anonymize_date(self, date_str: str, preserve_year: bool = True) -> str:
        """Anonymize date while optionally preserving year."""
        if not date_str:
            return "****-**-**"
        
        try:
            from datetime import datetime
            date_obj = datetime.fromisoformat(date_str.replace('Z', '+00:00'))
            
            if preserve_year:
                return f"{date_obj.year}-**-**"
            else:
                return "****-**-**"
        except ValueError:
            return "****-**-**"
    
    def pseudonymize_id(self, original_id: str) -> str:
        """Create consistent pseudonym for ID."""
        if not original_id:
            return "anon_" + ''.join(random.choices(string.ascii_lowercase + string.digits, k=8))
        
        # Create consistent hash-based pseudonym
        hash_input = f"{original_id}{self.salt}".encode()
        hash_digest = hashlib.sha256(hash_input).hexdigest()
        
        return f"anon_{hash_digest[:8]}"
    
    def anonymize_record(self, record: Dict[str, Any], schema: Dict[str, str]) -> Dict[str, Any]:
        """Anonymize entire record based on schema."""
        anonymized = {}
        
        for field, value in record.items():
            if field in schema:
                anonymization_type = schema[field]
                
                if anonymization_type == "email":
                    anonymized[field] = self.anonymize_email(str(value))
                elif anonymization_type == "phone":
                    anonymized[field] = self.anonymize_phone(str(value))
                elif anonymization_type == "name":
                    anonymized[field] = self.anonymize_name(str(value))
                elif anonymization_type == "date":
                    anonymized[field] = self.anonymize_date(str(value))
                elif anonymization_type == "id":
                    anonymized[field] = self.pseudonymize_id(str(value))
                elif anonymization_type == "remove":
                    # Completely remove sensitive fields
                    continue
                else:
                    anonymized[field] = value
            else:
                anonymized[field] = value
        
        return anonymized

# Anonymization schemas for different data types
ANONYMIZATION_SCHEMAS = {
    "user_export": {
        "id": "id",
        "email": "email",
        "full_name": "name",
        "phone_number": "phone",
        "date_of_birth": "date",
        "medical_record_number": "remove",
        "created_at": "date"
    },
    "analytics_data": {
        "user_id": "id",
        "email": "email",
        "name": "name",
        "ip_address": "remove",
        "user_agent": "remove"
    }
}

anonymizer = DataAnonymizer()
```

## Consent Management

### Consent Service

```python
# app/services/consent_service.py
from typing import List, Optional
from datetime import datetime

class ConsentService:
    """Service for managing user consent."""
    
    CONSENT_TYPES = [
        "data_processing",      # Basic data processing
        "marketing",           # Marketing communications
        "analytics",           # Usage analytics
        "third_party_sharing", # Sharing with partners
        "research",            # Medical research
    ]
    
    async def grant_consent(
        self,
        user_id: str,
        consent_type: str,
        consent_text: str,
        version: str
    ) -> ConsentRecord:
        """Grant user consent."""
        
        # Withdraw any existing consent for this type
        await self.withdraw_consent(user_id, consent_type)
        
        # Create new consent record
        consent = ConsentRecord(
            user_id=user_id,
            consent_type=consent_type,
            granted=True,
            consent_date=datetime.utcnow(),
            consent_text=consent_text,
            version=version
        )
        
        db.add(consent)
        await db.commit()
        
        # Log consent grant
        await self._log_consent_event(user_id, consent_type, "granted")
        
        return consent
    
    async def withdraw_consent(self, user_id: str, consent_type: str) -> bool:
        """Withdraw user consent."""
        
        existing_consent = await db.query(ConsentRecord).filter(
            ConsentRecord.user_id == user_id,
            ConsentRecord.consent_type == consent_type,
            ConsentRecord.granted == True,
            ConsentRecord.withdrawn_date.is_(None)
        ).first()
        
        if existing_consent:
            existing_consent.granted = False
            existing_consent.withdrawn_date = datetime.utcnow()
            
            await db.commit()
            
            # Log consent withdrawal
            await self._log_consent_event(user_id, consent_type, "withdrawn")
            
            # Trigger data processing stop for this consent type
            await self._handle_consent_withdrawal(user_id, consent_type)
            
            return True
        
        return False
    
    async def get_user_consents(self, user_id: str) -> List[ConsentRecord]:
        """Get all consents for a user."""
        return await db.query(ConsentRecord).filter(
            ConsentRecord.user_id == user_id
        ).order_by(ConsentRecord.consent_date.desc()).all()
    
    async def has_consent(self, user_id: str, consent_type: str) -> bool:
        """Check if user has given specific consent."""
        consent = await db.query(ConsentRecord).filter(
            ConsentRecord.user_id == user_id,
            ConsentRecord.consent_type == consent_type,
            ConsentRecord.granted == True,
            ConsentRecord.withdrawn_date.is_(None)
        ).first()
        
        return consent is not None
    
    async def _handle_consent_withdrawal(self, user_id: str, consent_type: str):
        """Handle data processing changes when consent is withdrawn."""
        
        if consent_type == "marketing":
            # Remove from marketing lists
            await marketing_service.unsubscribe_user(user_id)
        
        elif consent_type == "analytics":
            # Stop analytics tracking
            await analytics_service.opt_out_user(user_id)
        
        elif consent_type == "third_party_sharing":
            # Notify partners to stop processing
            await partner_service.revoke_data_sharing(user_id)
        
        elif consent_type == "research":
            # Remove from research datasets
            await research_service.anonymize_user_data(user_id)
    
    async def _log_consent_event(self, user_id: str, consent_type: str, action: str):
        """Log consent-related events."""
        logger.info(
            f"Consent {action}",
            extra={
                "user_id": user_id,
                "consent_type": consent_type,
                "action": action,
                "timestamp": datetime.utcnow().isoformat()
            }
        )

consent_service = ConsentService()
```

### Consent UI Components

```typescript
// components/ConsentManager.tsx
import React, { useState, useEffect } from 'react';
import { useConsent } from '../hooks/useConsent';

interface ConsentItem {
  type: string;
  title: string;
  description: string;
  required: boolean;
  granted: boolean;
}

export const ConsentManager: React.FC = () => {
  const { consents, updateConsent, loading } = useConsent();
  const [consentItems, setConsentItems] = useState<ConsentItem[]>([]);

  const consentTypes = [
    {
      type: 'data_processing',
      title: 'Data Processing',
      description: 'Allow us to process your personal data for core platform functionality.',
      required: true,
    },
    {
      type: 'marketing',
      title: 'Marketing Communications',
      description: 'Receive marketing emails about new features and health tips.',
      required: false,
    },
    {
      type: 'analytics',
      title: 'Usage Analytics',
      description: 'Help us improve the platform by sharing anonymous usage data.',
      required: false,
    },
    {
      type: 'research',
      title: 'Medical Research',
      description: 'Contribute to medical research with anonymized health data.',
      required: false,
    },
  ];

  useEffect(() => {
    const items = consentTypes.map(type => ({
      ...type,
      granted: consents.some(c => 
        c.consent_type === type.type && 
        c.granted && 
        !c.withdrawn_date
      ),
    }));
    setConsentItems(items);
  }, [consents]);

  const handleConsentChange = async (type: string, granted: boolean) => {
    await updateConsent(type, granted);
  };

  return (
    <div className="consent-manager">
      <h2>Privacy Preferences</h2>
      <p className="description">
        Manage your data privacy preferences. You can change these settings at any time.
      </p>
      
      <div className="consent-items">
        {consentItems.map(item => (
          <div key={item.type} className="consent-item">
            <div className="consent-header">
              <h3>{item.title}</h3>
              {item.required && <span className="required">Required</span>}
            </div>
            
            <p className="consent-description">{item.description}</p>
            
            <div className="consent-control">
              <label className="toggle">
                <input
                  type="checkbox"
                  checked={item.granted}
                  disabled={item.required || loading}
                  onChange={(e) => handleConsentChange(item.type, e.target.checked)}
                />
                <span className="slider"></span>
                <span className="label">
                  {item.granted ? 'Granted' : 'Not granted'}
                </span>
              </label>
            </div>
          </div>
        ))}
      </div>
      
      <div className="consent-footer">
        <p className="privacy-notice">
          For more information about how we handle your data, see our{' '}
          <a href="/privacy-policy" target="_blank">Privacy Policy</a>.
        </p>
      </div>
    </div>
  );
};
```

## Data Subject Rights (GDPR)

### Rights Management Service

```python
# app/services/rights_service.py
from typing import Dict, Any, List
import json
from datetime import datetime, timedelta

class DataSubjectRightsService:
    """Service for handling GDPR data subject rights."""
    
    async def handle_access_request(self, user_id: str) -> Dict[str, Any]:
        """Handle right to access - provide all user data."""
        
        # Collect all user data from different sources
        user_data = {
            "profile": await self._get_user_profile(user_id),
            "appointments": await self._get_user_appointments(user_id),
            "medical_records": await self._get_user_medical_records(user_id),
            "consent_history": await self._get_consent_history(user_id),
            "access_logs": await self._get_access_logs(user_id),
            "preferences": await self._get_user_preferences(user_id)
        }
        
        # Create export package
        export_package = {
            "request_date": datetime.utcnow().isoformat(),
            "user_id": user_id,
            "data": user_data,
            "data_sources": [
                "user_profiles",
                "appointments",
                "medical_records", 
                "consent_records",
                "access_logs",
                "user_preferences"
            ]
        }
        
        # Log the access request
        await self._log_rights_request(user_id, "access", "completed")
        
        return export_package
    
    async def handle_rectification_request(
        self, 
        user_id: str, 
        corrections: Dict[str, Any]
    ) -> Dict[str, Any]:
        """Handle right to rectification - correct inaccurate data."""
        
        result = {
            "corrected_fields": [],
            "failed_fields": [],
            "timestamp": datetime.utcnow().isoformat()
        }
        
        for field, new_value in corrections.items():
            try:
                await self._update_user_field(user_id, field, new_value)
                result["corrected_fields"].append(field)
            except Exception as e:
                result["failed_fields"].append({
                    "field": field,
                    "error": str(e)
                })
        
        await self._log_rights_request(user_id, "rectification", "completed")
        return result
    
    async def handle_erasure_request(self, user_id: str) -> Dict[str, Any]:
        """Handle right to erasure - delete user data."""
        
        # Check if erasure is possible (legal obligations, etc.)
        can_erase, reason = await self._can_erase_data(user_id)
        
        if not can_erase:
            await self._log_rights_request(user_id, "erasure", "rejected", reason)
            return {
                "status": "rejected",
                "reason": reason,
                "timestamp": datetime.utcnow().isoformat()
            }
        
        # Perform erasure
        erasure_results = {
            "user_profile": await self._erase_user_profile(user_id),
            "appointments": await self._erase_user_appointments(user_id),
            "medical_records": await self._anonymize_medical_records(user_id),  # Anonymize instead of delete
            "consent_records": await self._erase_consent_records(user_id),
            "access_logs": await self._anonymize_access_logs(user_id)
        }
        
        await self._log_rights_request(user_id, "erasure", "completed")
        
        return {
            "status": "completed",
            "erasure_results": erasure_results,
            "timestamp": datetime.utcnow().isoformat()
        }
    
    async def handle_portability_request(self, user_id: str, format_type: str = "json") -> Dict[str, Any]:
        """Handle right to data portability - export data in structured format."""
        
        # Get portable data (user-provided data only)
        portable_data = {
            "personal_info": await self._get_portable_profile_data(user_id),
            "preferences": await self._get_portable_preferences(user_id),
            "appointments": await self._get_portable_appointments(user_id),
            "uploaded_files": await self._get_portable_files(user_id)
        }
        
        if format_type == "csv":
            # Convert to CSV format
            export_data = await self._convert_to_csv(portable_data)
        elif format_type == "xml":
            # Convert to XML format  
            export_data = await self._convert_to_xml(portable_data)
        else:
            # Default JSON format
            export_data = portable_data
        
        await self._log_rights_request(user_id, "portability", "completed")
        
        return {
            "format": format_type,
            "data": export_data,
            "timestamp": datetime.utcnow().isoformat()
        }
    
    async def handle_objection_request(
        self, 
        user_id: str, 
        objection_types: List[str]
    ) -> Dict[str, Any]:
        """Handle right to object - stop specific data processing."""
        
        results = {}
        
        for objection_type in objection_types:
            if objection_type == "marketing":
                await marketing_service.opt_out_user(user_id)
                results["marketing"] = "opted_out"
                
            elif objection_type == "analytics":
                await analytics_service.disable_tracking(user_id)
                results["analytics"] = "disabled"
                
            elif objection_type == "profiling":
                await profiling_service.disable_profiling(user_id)
                results["profiling"] = "disabled"
                
            elif objection_type == "automated_decision_making":
                await ml_service.disable_automated_decisions(user_id)
                results["automated_decisions"] = "disabled"
        
        await self._log_rights_request(user_id, "objection", "completed")
        
        return {
            "objections_processed": results,
            "timestamp": datetime.utcnow().isoformat()
        }
    
    async def _can_erase_data(self, user_id: str) -> tuple[bool, Optional[str]]:
        """Check if user data can be erased."""
        
        # Check for legal obligations
        has_active_legal_case = await legal_service.has_active_case(user_id)
        if has_active_legal_case:
            return False, "Data required for legal proceedings"
        
        # Check for ongoing medical treatment
        has_active_treatment = await medical_service.has_active_treatment(user_id)
        if has_active_treatment:
            return False, "Data required for ongoing medical treatment"
        
        # Check for financial obligations
        has_outstanding_payments = await billing_service.has_outstanding_payments(user_id)
        if has_outstanding_payments:
            return False, "Data required for financial obligations"
        
        return True, None
    
    async def _log_rights_request(
        self, 
        user_id: str, 
        request_type: str, 
        status: str,
        notes: str = None
    ):
        """Log data subject rights requests."""
        logger.info(
            f"GDPR rights request: {request_type}",
            extra={
                "user_id": user_id,
                "request_type": request_type,
                "status": status,
                "notes": notes,
                "timestamp": datetime.utcnow().isoformat()
            }
        )

rights_service = DataSubjectRightsService()
```

## Security Monitoring

### Privacy Breach Detection

```python
# app/monitoring/privacy_monitor.py
from typing import List, Dict, Any
import asyncio

class PrivacyBreachMonitor:
    """Monitor for potential privacy breaches."""
    
    def __init__(self):
        self.alert_thresholds = {
            "bulk_data_access": 100,        # Accessing >100 records in short time
            "after_hours_access": True,     # Access outside business hours
            "multiple_user_access": 50,     # Accessing >50 different users
            "failed_access_attempts": 10,   # >10 failed attempts
            "data_export_volume": 1000,     # Exporting >1000 records
        }
    
    async def monitor_data_access(self, access_log: DataAccessLog):
        """Monitor data access patterns for potential breaches."""
        
        alerts = []
        
        # Check bulk access
        recent_access_count = await self._count_recent_access(
            access_log.accessor_id, 
            minutes=15
        )
        
        if recent_access_count > self.alert_thresholds["bulk_data_access"]:
            alerts.append(self._create_alert(
                "bulk_data_access",
                f"User {access_log.accessor_id} accessed {recent_access_count} records in 15 minutes",
                access_log
            ))
        
        # Check after-hours access
        if self._is_after_hours(access_log.timestamp):
            alerts.append(self._create_alert(
                "after_hours_access",
                f"Data access outside business hours",
                access_log
            ))
        
        # Check multiple user access
        unique_users_accessed = await self._count_unique_users_accessed(
            access_log.accessor_id,
            hours=1
        )
        
        if unique_users_accessed > self.alert_thresholds["multiple_user_access"]:
            alerts.append(self._create_alert(
                "multiple_user_access",
                f"Accessed data from {unique_users_accessed} different users in 1 hour",
                access_log
            ))
        
        # Send alerts
        for alert in alerts:
            await self._send_privacy_alert(alert)
    
    async def monitor_data_export(self, user_id: str, export_type: str, record_count: int):
        """Monitor data exports for potential breaches."""
        
        if record_count > self.alert_thresholds["data_export_volume"]:
            alert = {
                "type": "large_data_export",
                "message": f"Large data export: {record_count} records",
                "user_id": user_id,
                "export_type": export_type,
                "timestamp": datetime.utcnow().isoformat(),
                "severity": "high"
            }
            
            await self._send_privacy_alert(alert)
    
    async def _send_privacy_alert(self, alert: Dict[str, Any]):
        """Send privacy breach alert."""
        
        # Log alert
        logger.warning(
            f"Privacy alert: {alert['type']}",
            extra=alert
        )
        
        # Send to security team
        await notification_service.send_security_alert(
            recipient="security-team@medico24.com",
            subject=f"Privacy Alert: {alert['type']}",
            message=alert['message'],
            priority="high"
        )
        
        # Store in security incidents database
        await security_service.create_incident(
            incident_type="privacy_alert",
            severity=alert.get("severity", "medium"),
            details=alert
        )

privacy_monitor = PrivacyBreachMonitor()
```

## Data Retention and Disposal

### Automated Data Lifecycle Management

```python
# app/services/data_lifecycle_service.py
from datetime import datetime, timedelta
import asyncio

class DataLifecycleService:
    """Manage data retention and automated disposal."""
    
    RETENTION_POLICIES = {
        DataClassification.RESTRICTED: {
            "medical_records": 7 * 365,      # 7 years
            "consent_records": 7 * 365,      # 7 years  
            "access_logs": 3 * 365,          # 3 years
        },
        DataClassification.CONFIDENTIAL: {
            "user_profiles": 5 * 365,        # 5 years after account closure
            "appointments": 5 * 365,         # 5 years
            "communications": 2 * 365,       # 2 years
        },
        DataClassification.INTERNAL: {
            "system_logs": 1 * 365,          # 1 year
            "performance_metrics": 2 * 365,  # 2 years
            "error_logs": 6 * 30,            # 6 months
        }
    }
    
    async def run_retention_cleanup(self):
        """Run automated data retention cleanup."""
        
        logger.info("Starting data retention cleanup")
        
        # Process each data type
        for classification, policies in self.RETENTION_POLICIES.items():
            for data_type, retention_days in policies.items():
                await self._cleanup_expired_data(data_type, retention_days)
        
        logger.info("Data retention cleanup completed")
    
    async def _cleanup_expired_data(self, data_type: str, retention_days: int):
        """Clean up expired data of specific type."""
        
        cutoff_date = datetime.utcnow() - timedelta(days=retention_days)
        
        try:
            if data_type == "medical_records":
                await self._cleanup_medical_records(cutoff_date)
            elif data_type == "access_logs":
                await self._cleanup_access_logs(cutoff_date)
            elif data_type == "user_profiles":
                await self._cleanup_inactive_profiles(cutoff_date)
            elif data_type == "system_logs":
                await self._cleanup_system_logs(cutoff_date)
            
            logger.info(f"Cleaned up {data_type} older than {cutoff_date}")
            
        except Exception as e:
            logger.error(f"Error cleaning up {data_type}: {e}")
    
    async def _cleanup_medical_records(self, cutoff_date: datetime):
        """Clean up old medical records."""
        
        # Find records to anonymize (not delete due to medical requirements)
        old_records = await db.query(MedicalRecord).filter(
            MedicalRecord.created_at < cutoff_date,
            MedicalRecord.anonymized == False
        ).all()
        
        for record in old_records:
            # Anonymize rather than delete
            await self._anonymize_medical_record(record)
    
    async def _anonymize_medical_record(self, record: MedicalRecord):
        """Anonymize medical record while preserving medical data."""
        
        # Remove patient identifiers
        record.patient_id = anonymizer.pseudonymize_id(record.patient_id)
        record.patient_name = anonymizer.anonymize_name(record.patient_name)
        record.date_of_birth = anonymizer.anonymize_date(record.date_of_birth, preserve_year=True)
        
        # Keep medical data for research purposes
        # record.diagnosis, record.treatment, etc. remain unchanged
        
        record.anonymized = True
        record.anonymized_date = datetime.utcnow()
        
        await db.commit()
    
    async def schedule_user_data_deletion(self, user_id: str, deletion_date: datetime):
        """Schedule user data for future deletion."""
        
        deletion_task = DataDeletionTask(
            user_id=user_id,
            scheduled_date=deletion_date,
            status="scheduled",
            created_at=datetime.utcnow()
        )
        
        db.add(deletion_task)
        await db.commit()
    
    async def execute_scheduled_deletions(self):
        """Execute scheduled data deletions."""
        
        due_deletions = await db.query(DataDeletionTask).filter(
            DataDeletionTask.scheduled_date <= datetime.utcnow(),
            DataDeletionTask.status == "scheduled"
        ).all()
        
        for deletion_task in due_deletions:
            try:
                await self._execute_user_deletion(deletion_task.user_id)
                deletion_task.status = "completed"
                deletion_task.completed_at = datetime.utcnow()
                
            except Exception as e:
                deletion_task.status = "failed"
                deletion_task.error_message = str(e)
                logger.error(f"Failed to delete user data {deletion_task.user_id}: {e}")
        
        await db.commit()

# Scheduled tasks
@scheduler.scheduled_job('cron', hour=2, minute=0)  # Run daily at 2 AM
async def daily_data_cleanup():
    lifecycle_service = DataLifecycleService()
    await lifecycle_service.run_retention_cleanup()

@scheduler.scheduled_job('cron', hour=3, minute=0)  # Run daily at 3 AM
async def execute_scheduled_deletions():
    lifecycle_service = DataLifecycleService()
    await lifecycle_service.execute_scheduled_deletions()
```

## Compliance Reporting

### Automated Compliance Reports

```python
# app/reporting/compliance_reports.py
from typing import Dict, List, Any
import pandas as pd

class ComplianceReportGenerator:
    """Generate compliance reports for auditing."""
    
    async def generate_monthly_privacy_report(self, month: int, year: int) -> Dict[str, Any]:
        """Generate monthly privacy compliance report."""
        
        start_date = datetime(year, month, 1)
        if month == 12:
            end_date = datetime(year + 1, 1, 1) - timedelta(days=1)
        else:
            end_date = datetime(year, month + 1, 1) - timedelta(days=1)
        
        report = {
            "report_period": f"{year}-{month:02d}",
            "generated_at": datetime.utcnow().isoformat(),
            "data_subject_requests": await self._get_dsr_stats(start_date, end_date),
            "consent_management": await self._get_consent_stats(start_date, end_date),
            "data_breaches": await self._get_breach_stats(start_date, end_date),
            "access_patterns": await self._get_access_pattern_stats(start_date, end_date),
            "data_retention": await self._get_retention_stats(start_date, end_date)
        }
        
        return report
    
    async def _get_dsr_stats(self, start_date: datetime, end_date: datetime) -> Dict[str, Any]:
        """Get data subject request statistics."""
        
        # Count requests by type
        request_counts = {}
        for request_type in ["access", "rectification", "erasure", "portability", "objection"]:
            count = await db.query(DataSubjectRequest).filter(
                DataSubjectRequest.request_type == request_type,
                DataSubjectRequest.created_at.between(start_date, end_date)
            ).count()
            request_counts[request_type] = count
        
        # Average response time
        completed_requests = await db.query(DataSubjectRequest).filter(
            DataSubjectRequest.status == "completed",
            DataSubjectRequest.created_at.between(start_date, end_date)
        ).all()
        
        if completed_requests:
            response_times = [
                (req.completed_at - req.created_at).total_seconds() / 3600  # hours
                for req in completed_requests if req.completed_at
            ]
            avg_response_time = sum(response_times) / len(response_times)
        else:
            avg_response_time = 0
        
        return {
            "total_requests": sum(request_counts.values()),
            "requests_by_type": request_counts,
            "average_response_time_hours": round(avg_response_time, 2),
            "compliance_rate": self._calculate_compliance_rate(completed_requests)
        }
    
    async def generate_gdpr_audit_report(self) -> Dict[str, Any]:
        """Generate comprehensive GDPR audit report."""
        
        report = {
            "audit_date": datetime.utcnow().isoformat(),
            "data_inventory": await self._audit_data_inventory(),
            "legal_basis": await self._audit_legal_basis(),
            "consent_records": await self._audit_consent_records(),
            "data_transfers": await self._audit_data_transfers(),
            "security_measures": await self._audit_security_measures(),
            "breach_preparedness": await self._audit_breach_preparedness(),
            "staff_training": await self._audit_staff_training()
        }
        
        return report
    
    async def export_compliance_data(self, format_type: str = "xlsx") -> str:
        """Export compliance data for external audit."""
        
        # Collect all compliance-related data
        data = {
            "consent_records": await self._export_consent_data(),
            "data_processing_records": await self._export_processing_data(),
            "access_logs": await self._export_access_logs(),
            "breach_incidents": await self._export_breach_data(),
            "dsr_requests": await self._export_dsr_data()
        }
        
        if format_type == "xlsx":
            return await self._create_excel_export(data)
        elif format_type == "csv":
            return await self._create_csv_export(data)
        else:
            return json.dumps(data, indent=2)

compliance_reporter = ComplianceReportGenerator()
```

## Resources

- [HIPAA Compliance Guide](https://www.hhs.gov/hipaa/for-professionals/security/guidance/cybersecurity/index.html)
- [GDPR Implementation Guide](https://gdpr.eu/gdpr-compliance-guide/)
- [Data Anonymization Techniques](https://ico.org.uk/media/about-the-ico/consultations/2619862/anonymisation-consultation-paper.pdf)
- [Privacy by Design Principles](https://iapp.org/resources/article/privacy-by-design-the-7-foundational-principles/)
- [Healthcare Data Security](https://www.nist.gov/cyberframework/health)