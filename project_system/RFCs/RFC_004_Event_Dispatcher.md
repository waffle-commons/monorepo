# RFC-004: Event Dispatcher System

**Status:** Implemented (Alpha 5) **Components:** `waffle-commons/event-dispatcher` **Author:** Lead Observability **Tags:** psr-14, events, decoupling

## 1. Summary

This RFC details Waffle's "Nervous System". Waffle uses a PSR-14 compliant event dispatcher to decouple core framework logic from userland applications.

## 2. Motivation

In a robust framework, the core must remain closed to modification but open to extension (OCP). The Event Dispatcher allows developers to hook into the request lifecycle without overriding internal classes.

## 3. Technical Specifications

### 3.1 Architecture

- **EventDispatcher:** Implements `Psr\EventDispatcher\EventDispatcherInterface`.
    
- **ListenerProvider:** Maps events to callables.
    
- **Listeners:** Defined using the `#[AsEventListener]` attribute on classes or specific methods.
    

```
class WelcomeEmailListener
{
    #[AsEventListener(priority: 10)]
    public function onUserRegistered(UserRegisteredEvent $event): void { ... }
}
```

### 3.2 Core Lifecycle Events

The Kernel emits four native events:

1. `RequestReceivedEvent`
    
2. `ControllerArgumentsResolvedEvent`
    
3. `ResponseGeneratedEvent`
    
4. `TerminateEvent` (Crucial in FrankenPHP: allows heavy tasks like sending emails to run _after_ the HTTP connection is closed).
    

## 4. Contributor Guidelines

- **Event Purity:** Standard events should be immutable DTOs. If an event is designed to halt execution, it must explicitly implement `Psr\EventDispatcher\StoppableEventInterface`.
    
- **Constant Naming:** Use typed constants for event names in PHP 8.5 (`public const string EVENT_NAME = '...';`).