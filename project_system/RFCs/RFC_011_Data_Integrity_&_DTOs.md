# RFC-011: Data Integrity & DTOs (PHP 8.5)

**Status:** Planned for Alpha 6 **Components:** `waffle-commons/waffle` (ArgumentResolver) **Author:** Architect & Security Team **Tags:** php-8.5, property-hooks, validation, dto

## 1. Summary

This RFC introduces the paradigm shift for data validation in Waffle Alpha 6. We are abandoning heavy, annotation-based external validator libraries in favor of native PHP 8.5 Property Hooks within Data Transfer Objects (DTOs).

## 2. Motivation

External validators (like Symfony Validator) use reflection heavily and execute _after_ object instantiation, allowing invalid state to exist temporarily. By utilizing PHP 8.5 Property Hooks, we guarantee that a DTO cannot physically be instantiated with invalid data. It is a "Secure by Design" approach with zero performance overhead.

## 3. Technical Specifications

### 3.1 The Waffle Standard DTO

All incoming data (POST payloads, Query params) must be mapped to `readonly` classes. Validation logic lives exclusively inside the `set()` hook.

```
readonly class UserRegistrationDTO {
    public string $email {
        set(string $value) {
            if (!filter_var($value, FILTER_VALIDATE_EMAIL)) {
                throw new ValidationException('Invalid Email Format');
            }
            $this->email = $value;
        }
    }
}
```

### 3.2 ArgumentResolver Integration

The `ControllerArgumentResolver` will intercept JSON payloads from the PSR-7 request, attempt to hydrate the required DTO, and naturally trigger the Property Hooks. If a `ValidationException` is thrown, it is caught by the `ErrorHandlerMiddleware` to return an RFC 7807 HTTP 422 Unprocessable Entity response.

## 4. Contributor Guidelines

- **Purity:** Validation logic in hooks must be synchronous and pure (no database calls).
    
- **Exceptions:** Throw specific `ValidationException` instances with clear messages for the end-user API.