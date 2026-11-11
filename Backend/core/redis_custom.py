import redis.asyncio as aioredis

from core.config import settings


class RedisClient:
    def __init__(self):
        self._redis = aioredis.from_url(
            settings.REDIS_URL,
            encoding="utf-8",
            decode_responses=True,
        )

    async def close(self):
        if self._redis :
            await self._redis.aclose()

    @property
    def client(self):
        return self._redis

    async def get(self, key: str) -> str | None:
        return await self._redis.get(key)

    async def set(self, key: str, value: str, ex: int | None = None):
        await self._redis.set(key, value, ex=ex)

    async def delete(self, key: str):
        await self._redis.delete(key)

    async def exists(self, key: str) -> int:
        return await self._redis.exists(key)

    async def incr(self, key: str) -> int:
        """Tăng giá trị của key lên 1, trả về giá trị sau khi tăng."""
        return await self._redis.incr(key)

    async def expire(self, key: str, time: int) -> bool:
        """Cài đặt thời gian sống (giây) cho một key có sẵn."""
        return await self._redis.expire(key, time)


redis_client = RedisClient()
