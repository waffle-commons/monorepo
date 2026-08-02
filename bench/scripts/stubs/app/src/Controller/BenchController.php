<?php

declare(strict_types=1);

namespace App\Controller;

use App\Dto\GreetInput;
use Doctrine\DBAL\Connection;
use Symfony\Bundle\FrameworkBundle\Controller\AbstractController;
use Symfony\Component\HttpFoundation\JsonResponse;
use Symfony\Component\HttpFoundation\Request;
use Symfony\Component\HttpKernel\Attribute\MapRequestPayload;
use Symfony\Component\Routing\Attribute\Route;

/**
 * The 5 canonical bench workloads (see bench/README.md).
 *
 * This is a FAIR typical-Symfony baseline — idiomatic, neither sandbagged nor
 * hyper-optimized: AbstractController + attribute routing + JsonResponse +
 * MapRequestPayload (serializer + validator) + Doctrine DBAL. The HTTP contract
 * (methods, paths, payload shapes, status codes) is byte-identical to the
 * Waffle skeleton (engine A); response bodies are idiomatic per framework.
 */
final class BenchController extends AbstractController
{
    /** GET / — static JSON. */
    #[Route('/', name: 'bench_index', methods: ['GET'])]
    public function index(): JsonResponse
    {
        return new JsonResponse([
            'message' => 'Hello, World!',
            'framework' => 'symfony',
        ]);
    }

    /** GET /hello/{name} — JSON with routed param. */
    #[Route('/hello/{name}', name: 'bench_hello', methods: ['GET'])]
    public function hello(string $name): JsonResponse
    {
        return new JsonResponse([
            'message' => sprintf('Hello, %s!', $name),
        ]);
    }

    /**
     * POST /greet — JSON body {"name": ...} -> validated DTO -> JSON.
     * Mirrors engine A's DTO-hydration + validation cost (Waffle property-hook
     * validation vs Symfony serializer denormalization + validator).
     */
    #[Route('/greet', name: 'bench_greet', methods: ['POST'])]
    public function greet(#[MapRequestPayload] GreetInput $input): JsonResponse
    {
        return new JsonResponse([
            'message' => sprintf('Hello, %s!', $input->name),
        ]);
    }

    /** GET /read/demo?id=<uuid> — exactly one DBAL SELECT by primary key. */
    #[Route('/read/demo', name: 'bench_read', methods: ['GET'])]
    public function read(Request $request, Connection $connection): JsonResponse
    {
        $id = (string) $request->query->get('id', '');

        if ($id === '') {
            return new JsonResponse(['error' => 'missing id'], 400);
        }

        $row = $connection->fetchAssociative(
            'SELECT id, email, created_at FROM users WHERE id = ?',
            [$id],
        );

        // Response CONTRACT PARITY with Engine A (Waffle's ReadDemoController):
        // a miss is 200 {"found":false,"user":null}, not 404. A 404 here would
        // be more idiomatic REST, but it makes the engines non-comparable — k6
        // scores 404 as a failed request, so an id-scheme drift would surface as
        // "Symfony is broken" on B/C while staying invisible on A. Same status
        // and same body shape on every engine keeps the comparison honest.
        return new JsonResponse([
            'found' => $row !== false,
            'user' => $row === false ? null : $row,
        ]);
    }

    /**
     * POST /write/demo — exactly one DBAL INSERT, all values server-generated
     * (empty request body; created_at comes from the column default).
     */
    #[Route('/write/demo', name: 'bench_write', methods: ['POST'])]
    public function write(Connection $connection): JsonResponse
    {
        $id = $this->uuidV4();
        $email = bin2hex(random_bytes(8)) . '@bench.local';
        // Hash-SHAPED constant-cost value: password hashing (bcrypt/argon) is
        // deliberately NOT part of the workload on any engine — the write
        // demo measures the request pipeline + one INSERT, not KDF cost.
        $passwordHash = 'bench$' . bin2hex(random_bytes(16));

        $connection->executeStatement(
            'INSERT INTO users (id, email, password_hash) VALUES (?, ?, ?)',
            [$id, $email, $passwordHash],
        );

        return new JsonResponse(['id' => $id, 'email' => $email], 201);
    }

    /** RFC 4122 v4 UUID from random_bytes — no extra dependency. */
    private function uuidV4(): string
    {
        $bytes = random_bytes(16);
        $bytes[6] = chr((ord($bytes[6]) & 0x0f) | 0x40);
        $bytes[8] = chr((ord($bytes[8]) & 0x3f) | 0x80);

        return vsprintf('%s%s-%s-%s-%s-%s%s%s', str_split(bin2hex($bytes), 4));
    }
}
