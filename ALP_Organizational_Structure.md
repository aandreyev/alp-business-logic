# ALP Organizational Structure
## Single-Firm Architecture with Business Entities and Offices

### Overview

The ALP application is designed as a **single-firm system** (not multi-tenant) that supports multiple legal entities and office locations within one law firm. This architecture allows a single firm to manage different business entities, practice locations, and organizational structures while maintaining unified operations.

---

## 🏢 **Architecture Components**

### **BusinessEntity Model**
```csharp
public class BusinessEntity : BaseEntity
{
    public string LegalEntityName { get; set; }        // Legal name of entity
    public string? Abn { get; set; }                   // Australian Business Number
    public string? BankAccountName { get; set; }       // Banking details
    public string? BankAccountBsb { get; set; }
    public string? BankAccountNumber { get; set; }
    public string? BpayBillerCode { get; set; }
    public string? XeroClientId { get; set; }          // Accounting integration
    public string? XeroClientSecret { get; set; }
    public bool? isActive { get; set; }
    public int? AddressId { get; set; }
    public virtual Address Address { get; set; }
    public int? InvoicePaymentTimeframe { get; set; }
}
```

**Purpose**: Represents different legal entities that operate within the firm (e.g., different partnerships, corporations, or trading entities).

### **Office Model**
```csharp
public class Office : BaseEntity
{
    public string? Abbreviation { get; set; }          // Office abbreviation
    public string Phone { get; set; }                  // Office contact
    public string Website { get; set; }                // Office website
    public int AddressId { get; set; }                 // Physical location
    public int? BusinessEntityId { get; set; }         // Link to legal entity
    public bool? IsActive { get; set; }
    public virtual Address Address { get; set; }
    public virtual BusinessEntity BusinessEntity { get; set; }
}
```

**Purpose**: Represents physical office locations that can be associated with specific business entities.

### **User-Office Relationship**
```csharp
public class User : BaseEntity
{
    // ... other user fields
    public int? OfficeId { get; set; }                 // User's primary office
    public virtual Office Office { get; set; }
    // ... other relationships
}
```

**Purpose**: Associates users with their primary office location.

---

## 🔗 **Relationship Structure**

```
Single Law Firm Application
├── BusinessEntity (Legal Entity 1)
│   ├── Office (Location A)
│   │   └── Users (Lawyers/Staff at Location A)
│   └── Office (Location B)
│       └── Users (Lawyers/Staff at Location B)
├── BusinessEntity (Legal Entity 2)
│   └── Office (Location C)
│       └── Users (Lawyers/Staff at Location C)
└── BusinessEntity (Legal Entity 3)
    ├── Office (Location D)
    └── Office (Location E)
```

---

## 💼 **Business Use Cases**

### **Multiple Legal Entities**
- **Different Practice Areas**: Separate entities for different types of law
- **Partnership Structures**: Different partnership arrangements
- **Regulatory Compliance**: Separate entities for compliance requirements
- **Financial Separation**: Different banking and accounting arrangements

### **Multiple Offices**
- **Geographic Distribution**: Offices in different cities/regions
- **Specialization**: Offices focusing on different practice areas
- **Client Proximity**: Local offices for client convenience
- **Growth Strategy**: Expansion into new markets

### **Operational Benefits**
- **Unified Management**: Single system for all entities and offices
- **Resource Sharing**: Lawyers can work across entities/offices
- **Consolidated Reporting**: Firm-wide analytics and reporting
- **Consistent Processes**: Standardized workflows across locations

---

## 📊 **Data Architecture Implications**

### **Not Multi-Tenant**
- **Single Database**: All entities and offices share one database
- **No Tenant Separation**: No tenant-based data isolation
- **Shared Resources**: Users, matters, and data can span entities/offices

### **Organizational Filtering**
- **Office-Based Reporting**: Filter data by office for location-specific analysis
- **Entity-Based Reporting**: Filter data by business entity for legal/financial separation
- **Cross-Entity Analysis**: Analyze data across the entire firm

### **User Access Patterns**
- Users belong to a primary office but can work across the firm
- Matter assignments can cross office and entity boundaries
- Reporting can be filtered by office, entity, or firm-wide

---

## 🔧 **Technical Implementation**

### **Database Queries**
```sql
-- Office-specific analysis
SELECT * FROM matters m
JOIN users u ON m.coordinator_id = u.id
WHERE u.office_id = 1;

-- Entity-specific analysis  
SELECT * FROM matters m
JOIN users u ON m.coordinator_id = u.id
JOIN offices o ON u.office_id = o.id
WHERE o.business_entity_id = 1;

-- Cross-entity firm analysis
SELECT 
    be.legal_entity_name,
    o.abbreviation as office,
    COUNT(m.id) as matter_count
FROM business_entities be
JOIN offices o ON be.id = o.business_entity_id
JOIN users u ON o.id = u.office_id
JOIN matters m ON u.id = m.coordinator_id
GROUP BY be.id, o.id;
```

### **Application Logic**
- Office selection in user profiles
- Entity-based invoice generation
- Cross-office resource allocation
- Firm-wide performance metrics

---

## ⚠️ **Important Clarifications**

### **NOT Multi-Tenant**
- Application serves **one law firm only**
- No tenant isolation or separation
- No per-tenant configuration or data isolation

### **Multi-Entity Within Single Firm**
- **Business Entities**: Different legal entities within the firm
- **Offices**: Different physical locations within the firm
- **Unified Operations**: All operate under one application instance

### **Common Misconceptions Corrected**
- ❌ "Multi-tenant system with tenant separation"
- ✅ "Single-firm system with entity and office management"
- ❌ "Separate databases per tenant"
- ✅ "Single database with organizational structure"

---

This architecture provides the flexibility of multiple legal entities and offices while maintaining the operational simplicity and data consistency of a single-firm system.