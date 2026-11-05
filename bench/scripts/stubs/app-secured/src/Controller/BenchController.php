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
use Symfony\Component\Security\Http\Attribute\IsGranted;

/**
 * Engine D (equivalent features): the 5 canonical bench workloads of the bare
 * stub (bench/scripts/stubs/app/), with two differences that mirror Engine A:
 *
 *   - every action carries #[IsGranted('PUBLIC_ACCESS')], the counterpart of
 *     the skeleton's #[PublicAccess], so authorisation is decided per action
 *     after routing, as Waffle's SecurityMiddleware does;
 *   - POST /write/demo runs its statement inside the transaction that
 *     App\EventSubscriber\TransactionSubscriber opened for the request, as the
 *     skeleton's WriteDemoController does under TransactionIsolationMiddleware.
 *
 * Paths, methods, payloads, status codes and response bodies are the bare
 * stub's; its comments hold the parity notes behind each workload.
 */
final class BenchController extends AbstractController
{
    /** GET / — static JSON. */
    #[Route('/', name: 'bench_index', methods: ['GET'])]
    #[IsGranted('PUBLIC_ACCESS')]
    public function index(): JsonResponse
    {
        return new JsonResponse([
            'message' => 'Hello, World!',
            'framework' => 'symfony',
        ]);
    }

    /** GET /hello/{name} — JSON with routed param. */
    #[Route('/hello/{name}', name: 'bench_hello', methods: ['GET'])]
    #[IsGranted('PUBLIC_ACCESS')]
    public function hello(string $name): JsonResponse
    {
        return new JsonResponse([
            'message' => sprintf('Hello, %s!', $name),
        ]);
    }

    /** POST /greet — JSON body {"name": ...} -> validated DTO -> JSON, inside the request's transaction. */
    #[Route('/greet', name: 'bench_greet', methods: ['POST'])]
    #[IsGranted('PUBLIC_ACCESS')]
    public function greet(#[MapRequestPayload] GreetInput $input): JsonResponse
    {
        return new JsonResponse([
            'message' => sprintf('Hello, %s!', $input->name),
        ]);
    }

    /** GET /read/demo?id=<uuid> — exactly one DBAL SELECT by primary key (same projection as Engine A). */
    #[Route('/read/demo', name: 'bench_read', methods: ['GET'])]
    #[IsGranted('PUBLIC_ACCESS')]
    public function read(Request $request, Connection $connection): JsonResponse
    {
        $id = (string) $request->query->get('id', '');
        if ($id === '') {
            return new JsonResponse(['error' => 'missing id'], 400);
        }

        $row = $connection->fetchAssociative(
            'SELECT id, created_at FROM users WHERE id = ?',
            [$id],
        );

        return new JsonResponse([
            'found' => $row !== false,
            'user' => $row === false ? null : $row,
        ]);
    }

    /**
     * POST /write/demo — BEGIN (subscriber) + SELECT 1 + COMMIT (subscriber),
     * Engine A's transactional round trip. Opening a transaction here as well
     * would nest it, and DBAL 4 turns a nested transaction into savepoints: two
     * round trips Engine A does not make.
     */
    #[Route('/write/demo', name: 'bench_write', methods: ['POST'])]
    #[IsGranted('PUBLIC_ACCESS')]
    public function write(Connection $connection): JsonResponse
    {
        $applied = $connection->fetchOne('SELECT 1') !== false;

        return new JsonResponse(['written' => $applied, 'in_transaction' => $connection->isTransactionActive()]);
    }
}
