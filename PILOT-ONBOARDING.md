# SCENTS/WISMO Pilot Onboarding Guide

## Welcome to the SCENTS/WISMO Pilot

Thank you for joining our pilot program. This guide will help you get started with the SCENTS/WISMO platform for logistics, rider dispatch, and situational awareness.

---

## Table of Contents
1. [Quick Start](#quick-start)
2. [For Merchants](#for-merchants)
3. [For Riders](#for-riders)
4. [Platform Features](#platform-features)
5. [Support & Escalation](#support--escalation)
6. [FAQ](#faq)

---

## Quick Start

### Your Credentials
- **Platform URL**: https://your-domain.com (or http://localhost:3000 for testing)
- **Pilot Token**: `pilot-token`
- **Role**: Admin / Merchant / Rider (varies by user)

### First Steps
1. Open the platform in your browser
2. Sign in with your email or phone number
3. Select your role: Merchant or Rider
4. Complete your profile
5. Start using the platform

---

## For Merchants

### Creating Your First Order

1. **Navigate to Orders**
   - Click "New Order" in the dashboard
   - Or use API: `POST /api/orders` with your auth token

2. **Fill Order Details**
   - Origin address
   - Destination address
   - Package value
   - Delivery instructions

3. **Submit & Track**
   - Order is assigned to an available rider
   - Track real-time location on the map
   - Receive notifications at each stage

### Dashboard Features

- **Order Management**: View all orders, filter by status
- **Rider Assignment**: See assigned riders and their status
- **Analytics**: View delivery times, success rates, rider performance
- **Alerts**: OSINT-powered alerts for traffic, weather, or security incidents

### API Access

```bash
# List your orders
curl -H "Authorization: Bearer pilot-token" \
  http://localhost:8080/api/orders

# Create a new order
curl -X POST \
  -H "Authorization: Bearer pilot-token" \
  -H "Content-Type: application/json" \
  -d '{"origin":"Nairobi CBD","destination":"Westlands","value":2500}' \
  http://localhost:8080/api/orders
```

---

## For Riders

### Accepting Deliveries

1. **View Available Orders**
   - Open the rider app
   - See orders near your location
   - Check payout and distance

2. **Accept & Navigate**
   - Tap to accept
   - Get turn-by-turn navigation
   - Mark as picked up / delivered

3. **Earn & Track**
   - View your earnings dashboard
   - Track completion rate
   - See ratings from merchants

### Rider App Features

- **GPS Navigation**: Optimized routes
- **In-App Chat**: Communicate with merchants
- **Safety Alerts**: OSINT alerts for your zone
- ** Earnings**: Real-time payout tracking

---

## Platform Features

### 1. Order Tracking
- Real-time GPS tracking
- Status updates: pending → assigned → in_transit → delivered
- SMS/email notifications

### 2. Rider Dispatch
- Automatic assignment based on proximity and availability
- Manual override for merchants
- Performance metrics for riders

### 3. OSINT Alerts
- Weather warnings (heavy rain, storms)
- Traffic incidents and road closures
- Security alerts in your delivery zone
- Tender and regulatory updates (for merchants)

### 4. Admin Dashboard
- Monitor all merchants, riders, and orders
- View audit logs and compliance reports
- Manage tenant settings and rate limits

### 5. Billing & Invoices
- Automatic invoice generation
- Usage-based billing
- Stripe payment integration

---

## Support & Escalation

### Pilot Support Channel
- **Slack**: #scents-pilot-support
- **Email**: pilot-support@scents-iq-ltd7.com
- **Phone**: +254-XXX-XXXXXX (during business hours)

### SLA Commitments
- **Response Time**: < 4 hours during business hours
- **Resolution Time**: < 24 hours for critical issues
- **Uptime Target**: 99.5% during pilot phase

### Escalation Path
1. **Level 1**: Support agent (Slack/email)
2. **Level 2**: Engineering lead (for technical issues)
3. **Level 3**: Platform owner (for critical outages)

### Emergency Contacts
- **Platform Outage**: Call +254-XXX-XXXXXX
- **Payment Issues**: payments@scents-iq-ltd7.com
- **Security Issues**: security@scents-iq-ltd7.com

---

## FAQ

### Q: How do I reset my password?
A: Use the "Forgot Password" link on the login page, or contact support.

### Q: Can I change my delivery zone?
A: Yes, contact support to update your zone assignment.

### Q: How are rider payouts calculated?
A: Payouts are based on distance, delivery time, and platform fee. See your earnings dashboard for details.

### Q: What happens if an order is cancelled?
A: Cancellation policies apply. Merchants may incur a fee if cancelled after rider assignment.

### Q: How do I report a bug?
A: Email pilot-support@scents-iq-ltd7.com with:
- Device/browser
- Steps to reproduce
- Screenshot if applicable

### Q: Is my data secure?
A: Yes. We use TLS encryption, role-based access control, and regular security audits. See our security whitepaper for details.

---

## Next Steps

1. **Complete your profile** in the app
2. **Create your first order** as a merchant or accept your first delivery as a rider
3. **Join the Slack channel** for real-time support
4. **Schedule a weekly check-in** with the pilot team

---

## Feedback

We value your feedback. Please share:
- What you like
- What's confusing
- Features you need
- Bugs you encounter

Feedback form: https://forms.example.com/scents-pilot-feedback

---

Thank you for being part of the SCENTS/WISMO pilot!

**Pilot Dates**: [Start Date] - [End Date]
**Target Go-Live**: [Date]
