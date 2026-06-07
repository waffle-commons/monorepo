# RFC-020: Waffle Maker (Scaffolding Engine)

**Status:** Approved (Planned for Beta 1)

**Components:** `waffle-commons/console`

**Author:** Lead Platform Architect & DevSecOps

**Tags:** console, cli, dx, scaffolding, php-8.5

**Reference RFC:** RFC-018 (Developer Experience & Tooling)

## 1. Summary

This RFC specifies the detailed structural design, template compilation algorithms, file writing policies, and security boundaries of **Waffle Maker**, the official code generation and scaffolding engine for the Waffle Framework.

First proposed as a core DX milestone in **RFC-018 (Section 3.1)**, Waffle Maker is designed to extend the console component (`waffle-commons/console`) with safe, high-performance scaffolding commands. This specification details how Waffle Maker generates perfectly formed, zero-debt PHP 8.5 structures while running under restricted local and containerized environments.

## 2. Motivation & Relations to RFC-018

### 2.1 The Architectural Drift Challenge

As established in RFC-018, maintaining a uniform code standard across more than 15 independent submodules is a major operational challenge. Manual file creation leads to structural drift: developers occasionally omit strict types declarations, misuse asymmetric visibility flags, or bypass critical security layers.

### 2.2 Alignment with RFC-018

RFC-018 laid out the motivational groundwork and high-level requirements for scaffolding controllers, middlewares, voters, and Data Transfer Objects (DTOs). This RFC (RFC-020) serves as the exhaustive engineering design companion to RFC-018. It expands the initial scope to address key Beta 1 pipeline needs, establishing concrete specifications for:

- Standardized, non-blocking HTTP Clients (`make:http-client`).
    
- Injectable CLI Command classes (`make:command`).
    
- Coordinated PSR-14 Event/Listener pairs (`make:event-pair`).
    

### 2.3 The Performance Constraint

Unlike legacy PHP generator bundles that carry heavy, third-party templating libraries (such as Twig or Blade) and run slow runtime AST-parsing engines, Waffle Maker must remain extremely lightweight. It must run with an $O(1)$ memory footprint inside persistent-memory environments like FrankenPHP worker mode, without polluting shared server states.

## 3. Technical Specifications

### 3.1 Subsystem Pipeline & Filesystem Layout

The scaffolding engine is encapsulated within the `console` component namespace (`Waffle\Commons\Console\Maker`), ensuring it only communicates with the rest of the application via established contract interfaces.

The physical file layout within `waffle-commons/console` is structured as follows:

- **`Maker/AbstractMakerCommand.php`**: The abstract console command base class, enforcing common options, safe file-writing operations, and interactive argument prompting.
    
- **`Maker/TemplateRenderer.php`**: The stateless template compilation engine.
    
- **`Maker/Generator/PropertyHookGenerator.php`**: The translation utility responsible for converting command-line types into native PHP 8.5 validation code blocks.
    
- **`Maker/Command/`**: The distinct command classes implementing the CLI input-output mappings.
    
- **`Maker/Stubs/`**: Non-executable, plain text template files (`.stub`) serving as blueprint skeletons.
    

### 3.2 The Indentation-Aware Template Compilation Algorithm

The `TemplateRenderer` is a stateless, memory-bounded text compiler. It reads raw `.stub` files and performs sequential string replacements based on token keys enclosed in double braces (`{{ KEY }}`).

To prevent generated files from failing the strict **Mago Purge Protocol** (such as indentation or trailing spacing rules), the renderer implements an **Indentation Preservation Algorithm**:

1. **Stream Parsing**: The compiler splits the stub content into an array of lines.
    
2. **Token Detection**: For each line, the engine checks for the presence of a double-braced token.
    
3. **Indentation Extraction**: If a token is detected, the leading whitespace characters (spaces or tabs) of that specific line are captured.
    
4. **Multiline Propagation**: If the replacement value is multiline, the captured leading indentation is prepended to every subsequent line of the injected value, ensuring the generated PHP code perfectly matches the surrounding context's structural nesting.
    
5. **Write Phase**: The compiled lines are reassembled and prepared for the secure disk-writing pipeline.
    

## 4. Scaffolding Commands Specifications

Every generator command inherits from `AbstractMakerCommand`, ensuring consistent behavior, path resolution, and terminal visual styles across the entire toolchain.

Commands are executed on the host-side wrapper using the unified binary signature: `bin/waffle make:[command] [arguments] [options]`

### 4.1 `make:controller`

Generates a route-mapped, immutable HTTP controller.

- **Signature:** `bin/waffle make:controller [Name] [--route=/path] [--priority=0]`
    
- **Generation Output Specifications:**
    
    - Creates a final class extending `BaseController` under the `Controller` namespace of the target repository.
        
    - Attaches a single native `#[Route]` attribute to the index method.
        
    - Includes a default JSON-response return signature.
        

### 4.2 `make:dto`

Generates a highly secure, final readonly Data Transfer Object (DTO) designed to prevent Mass Assignment and state corruption.

- **Signature:** `bin/waffle make:dto [Name] [fields...]` (e.g. `bin/waffle make:dto Register email:string age:int`)
    
- **Generation Output Specifications:**
    
    - Creates a final readonly class marked with Waffle's native `#[Dto]` class attribute.
        
    - Leverages promoted constructor properties.
        
    - **Property Hook Translation:** The `PropertyHookGenerator` parses input fields. For types like `string` or `int`, it appends a native `set` hook to the property. This hook checks incoming data and throws a `ValidationException` on failure (e.g., executing `FILTER_VALIDATE_EMAIL` on fields named `email`).
        

### 4.3 `make:middleware`

Generates a standard PSR-15 HTTP middleware class.

- **Signature:** `bin/waffle make:middleware [Name]`
    
- **Generation Output Specifications:**
    
    - Creates a final readonly class implementing `Psr\Http\Server\MiddlewareInterface` under the `Middleware` namespace.
        
    - Implements the `process()` method with a default forward-chained request handler delegation call.
        
    - Appends the standard `#[\Override]` PHP attribute on the implementation method.
        

### 4.4 `make:voter`

Generates a granual Attribute-Based Access Control (ABAC) security voter.

- **Signature:** `bin/waffle make:voter [Name]`
    
- **Generation Output Specifications:**
    
    - Creates a final readonly class implementing `Waffle\Commons\Contracts\Security\VoterInterface` under the `Security\Voter` namespace.
        
    - Implements the `decide()` method.
        
    - **Defensive Guard:** The default return value of `decide()` must be hardcoded to `false` (Fail-Closed principle).
        

### 4.5 `make:http-client` (Beta 1)

Generates a structured, final readonly PSR-18 HTTP Client wrapped in Waffle's security architecture.

- **Signature:** `bin/waffle make:http-client [Name] [--base-uri=http://api.internal]`
    
- **Generation Output Specifications:**
    
    - Creates a final readonly class in the `Service` namespace of the target package.
        
    - Injects a PSR-18 `ClientInterface` instance via constructor promotion.
        
    - Automatically wraps outgoing requests to target the specified base URI.
        
    - Standardizes error trapping, ensuring all network failures translate to `HttpClientExceptionInterface` instances.
        

### 4.6 `make:command` (Beta 1)

Generates an executable command-line console class.

- **Signature:** `bin/waffle make:command [Name] [--command-name=app:custom-task]`
    
- **Generation Output Specifications:**
    
    - Creates a final class extending `AbstractCommand` under the `Console\Command` namespace.
        
    - Overrides the `configure()` method to establish the command name and description.
        
    - Overrides the `execute()` method, returning a valid `ExitCode` backing integer.
        

### 4.7 `make:event-pair` (Beta 1)

Generates a coordinated PSR-14 Event DTO and its accompanying Listener.

- **Signature:** `bin/waffle make:event-pair [Name]`
    
- **Generation Output Specifications:**
    
    - **The Event Class:** Creates a final class extending `AbstractStoppableEvent` under the `Event` namespace.
        
    - **The Listener Class:** Creates a final readonly class under the `Event\Listener` namespace.
        
    - **Annotation-Free Wiring:** Attaches the `#[AsEventListener]` attribute to the listener's `__invoke` method, enabling zero-configuration auto-wiring during the kernel's boot phase.
        

## 5. Security & Disk Write Conventions

To prevent permission escalations, race conditions, or unformatted code from reaching production, the scaffolding engine enforces strict physical boundaries:

1. **Anti-Overwrite Shield:** If the target class file already exists on the physical storage, the command must abort immediately with a high-visibility error on `stderr`. File overwriting is strictly blocked unless the `--force` (or `-f`) flag is explicitly passed.
    
2. **Atomic Writing (Anti-OWASP A05:2021):** To prevent concurrency corruptions within shared developer environments, files are first compiled in a temporary directory, and then atomically moved to their destination via a standard system rename.
    
3. **Secure Permissions:** All folders created dynamically during the generation process must be locked down with strict directory permissions (`0755`).
    
4. **Automatic Namespace Extraction:** The root namespace of the target folder must never be hardcoded or guessed. The base maker command must read the local package's `composer.json` file and parse the `autoload.psr-4` configuration block to deduce the exact namespace structure dynamically.
    

## 6. Definition of Done (DoD)

Waffle Maker implementations are certified as complete once the following gates are satisfied:

- **Zero-Debt Scaffolding:** 100% of all generated code stubs must pass `mago lint` and `mago analyze` with exactly **zero errors and zero warnings** without requiring any baseline suppressions.
    
- **Virtual I/O Tests (>= 95% Coverage):** Command unit-tests must run successfully. To avoid disk-cluttering and test environment pollution on the host, file manipulation tests must run entirely inside an in-memory virtual file system.
    
- **Unified CLI Interface:** All commands must be registered explicitly in the application console factory, ensuring the "Zero-Magic" philosophy of the framework is respected.