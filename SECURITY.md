# Security Policy

## Supported Versions

The following versions of Abandoned Explorer are currently being supported with security updates:

| Version | Supported          |
| ------- | ------------------ |
| 1.0.x   | :white_check_mark: |

## Reporting a Vulnerability

If you discover a security vulnerability within Abandoned Explorer, please send an email to the project maintainer. All security vulnerabilities will be promptly addressed.

**Please do not report security vulnerabilities through public GitHub issues.**

### Contact Information

- **Email**: zvarazoku9@icloud.com
- **GitHub**: [@BRMilev22](https://github.com/BRMilev22)

### When reporting, please include:

1. **Description** of the vulnerability
2. **Steps to reproduce** the issue
3. **Potential impact** of the vulnerability
4. **Affected components** (iOS app, API, database)
5. **Suggested fix** (if you have one)

## Response Timeline

- **Initial Response**: Within 48 hours of receiving the report
- **Status Update**: Within 7 days with either a fix timeline or explanation
- **Resolution**: Security fixes will be prioritized and released as soon as possible

## Security Measures

Abandoned Explorer implements several security measures to protect user data and location information:

### Data Protection
- **JWT Authentication** with secure token management
- **Password hashing** using bcrypt with salt rounds
- **Input validation** and sanitization on all API endpoints
- **SQL injection prevention** with parameterized queries
- **XSS protection** using Helmet.js middleware

### API Security
- **Rate limiting** (100 requests/15 minutes per IP) to prevent abuse
- **CORS configuration** for cross-origin request management
- **Secure headers** implemented across all endpoints
- **Request logging** for monitoring and audit trails

### Database Security
- **Spatial data protection** for location coordinates
- **Foreign key constraints** for data integrity
- **Connection pooling** with secure connection management
- **Regular security updates** and patches

### iOS App Security
- **Secure API communication** with HTTPS
- **Local data encryption** for sensitive information
- **Location permission management** with user consent
- **Secure media upload** with file validation

### Location Data Security
- **Privacy protection** for user-submitted locations
- **Admin approval workflow** for new location submissions
- **Content moderation** for inappropriate submissions
- **Geographical data anonymization** where appropriate

## Best Practices for Users

To ensure the security of your Abandoned Explorer installation:

### For Developers
1. **Keep dependencies updated** - Regularly update Node.js packages and iOS dependencies
2. **Secure API keys** - Store API keys securely and never commit them to version control
3. **Use HTTPS** - Always use encrypted connections in production
4. **Monitor logs** - Regularly review API logs for suspicious activity
5. **Database security** - Use strong passwords and restrict database access

### For Users
1. **Strong passwords** - Use strong, unique passwords for your account
2. **Location privacy** - Be mindful of the locations you share and submit
3. **Report issues** - Report suspicious activity or inappropriate content
4. **Keep app updated** - Always use the latest version of the iOS app

## Security Updates

Security updates will be released as needed and announced through:
- GitHub repository releases
- Repository README updates
- Direct communication to users when critical

## Compliance and Standards

Abandoned Explorer follows industry security standards:
- **OWASP Top 10** guidelines for web application security
- **iOS Security Guidelines** for mobile app development
- **Data protection** best practices for location-based services
- **Privacy by design** principles for user data handling

## Acknowledgments

We appreciate the security research community and encourage responsible disclosure of any security vulnerabilities found in Abandoned Explorer.

---

**Note**: This security policy applies to the Abandoned Explorer iOS application, Node.js API, and MySQL database. For issues related to third-party services (MapBox, AWS, etc.), please refer to their respective security policies.