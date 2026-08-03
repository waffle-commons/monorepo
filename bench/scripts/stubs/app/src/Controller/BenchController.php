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
     * POST /write/demo — the TRANSACTIONAL ROUND-TRIP workload.
     *
     * WORKLOAD PARITY (read before changing this method).
     * ---------------------------------------------------
     * This must perform the SAME work as Engine A's counterpart, and Engine A
     * (skeleton's WriteDemoController) deliberately does NOT write: it issues
     * `SELECT 1` on a pooled connection that the framework's
     * TransactionIsolationMiddleware has already wrapped in a transaction,
     * because the endpoint is public and CSRF-exempt and must not commit
     * durable rows on every anonymous call.
     *
     * An earlier revision of this stub issued a real INSERT in autocommit. That
     * made "dbwrite" two different workloads — INSERT-without-transaction here
     * versus BEGIN + SELECT 1 + COMMIT there — so the two engines were not
     * comparable and the resulting numbers were meaningless in both directions.
     * Mirroring Engine A is the only way to keep the comparison honest without
     * shipping a public durable-write endpoint in the reference template.
     *
     * What this therefore measures on every engine: the request pipeline, an
     * explicit transaction boundary, and one trivial statement — NOT the cost
     * of a durable write.
     */
    #[Route('/write/demo', name: 'bench_write', methods: ['POST'])]
    public function write(Connection $connection): JsonResponse
    {
        $connection->beginTransaction();

        try {
            $applied = $connection->fetchOne('SELECT 1') !== false;
            $inTransaction = $connection->isTransactionActive();
            $connection->commit();
        } catch (\Throwable $e) {
            $connection->rollBack();

            throw $e;
        }

        return new JsonResponse(['written' => $applied, 'in_transaction' => $inTransaction]);
    }
}
