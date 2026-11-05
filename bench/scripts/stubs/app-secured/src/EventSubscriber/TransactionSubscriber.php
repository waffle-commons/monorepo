<?php

declare(strict_types=1);

namespace App\EventSubscriber;

use Doctrine\DBAL\Connection;
use Symfony\Component\EventDispatcher\EventSubscriberInterface;
use Symfony\Component\HttpFoundation\Request;
use Symfony\Component\HttpKernel\Event\ControllerArgumentsEvent;
use Symfony\Component\HttpKernel\Event\ExceptionEvent;
use Symfony\Component\HttpKernel\Event\ResponseEvent;
use Symfony\Component\HttpKernel\KernelEvents;

/**
 * Engine D's counterpart of Waffle's TransactionIsolationMiddleware: every
 * POST, PUT, PATCH or DELETE runs in one transaction, committed with the
 * response and rolled back on an exception. On the bench that is POST /greet,
 * which touches no table on either engine, and POST /write/demo.
 *
 * The transaction opens after the #[IsGranted] check (IsGrantedAttributeListener,
 * priority 20) and before the request payload is mapped and validated (priority
 * 0): Waffle's order is Security, then the transaction, then the dispatcher.
 * The open transaction is marked on the request, never on this service, so
 * nothing survives the request in a worker.
 */
final readonly class TransactionSubscriber implements EventSubscriberInterface
{
    private const array WRITE_METHODS = ['POST', 'PUT', 'PATCH', 'DELETE'];

    private const string OPEN = '_bench_transaction';

    public function __construct(
        private Connection $connection,
    ) {}

    #[\Override]
    public static function getSubscribedEvents(): array
    {
        return [
            KernelEvents::CONTROLLER_ARGUMENTS => ['begin', 10],
            KernelEvents::RESPONSE => 'commit',
            KernelEvents::EXCEPTION => 'rollBack',
        ];
    }

    public function begin(ControllerArgumentsEvent $event): void
    {
        $request = $event->getRequest();
        if (!$event->isMainRequest() || !in_array($request->getMethod(), self::WRITE_METHODS, true)) {
            return;
        }

        $this->connection->beginTransaction();
        $request->attributes->set(self::OPEN, true);
    }

    public function commit(ResponseEvent $event): void
    {
        if ($this->release($event->getRequest())) {
            $this->connection->commit();
        }
    }

    public function rollBack(ExceptionEvent $event): void
    {
        if ($this->release($event->getRequest())) {
            $this->connection->rollBack();
        }
    }

    /** True once per request that this subscriber opened a transaction for. */
    private function release(Request $request): bool
    {
        if (!$request->attributes->getBoolean(self::OPEN)) {
            return false;
        }

        $request->attributes->remove(self::OPEN);

        return $this->connection->isTransactionActive();
    }
}
