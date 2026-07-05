import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

async function main() {
  console.log('Starting database seed...');

  await prisma.otp.deleteMany();
  await prisma.user.deleteMany();

  const testUser = await prisma.user.create({
    data: {
      phoneNumber: '+919876543210',
      name: 'Test User',
      isVerified: true,
    },
  });

  console.log(`Created test user: ${testUser.phoneNumber} (id: ${testUser.id})`);
  console.log('Database seeding completed successfully.');
}

main()
  .catch((e) => {
    console.error('Seeding failed:', e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
