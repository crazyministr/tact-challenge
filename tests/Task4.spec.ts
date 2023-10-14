import '@ton-community/test-utils';
import { Blockchain, SandboxContract } from '@ton-community/sandbox';
import { beginCell, toNano } from 'ton-core';
import { Task4 } from '../wrappers/Task4';

describe('Task4', () => {
    let blockchain: Blockchain;
    let task4: SandboxContract<Task4>;

    beforeEach(async () => {
        blockchain = await Blockchain.create();
        task4 = blockchain.openContract(await Task4.fromInit(1n));
        const deployer = await blockchain.treasury('deployer');
        const deployResult = await task4.send(
            deployer.getSender(),
            {
                value: toNano('0.05'),
            },
            {
                $$type: 'Deploy',
                queryId: 0n,
            }
        );
        expect(deployResult.transactions).toHaveTransaction({
            from: deployer.address,
            to: task4.address,
            deploy: true,
            success: true,
        });
    });

    it('test', async () => {
        const deployer = await blockchain.treasury('deployer');

        const res1 = await task4.getTime()
        console.log('time left', res1)

        const res2 = await task4.getNft()
        console.log('get nft', res2)

        const res3 = await task4.getOwner()
        console.log('owner', res3)
        const resCallOwnershipAssigned = await task4.send(  deployer.getSender(),    {
            value: toNano('0.05'),
        }, {
            $$type: 'OwnershipAssigned',
            queryId: 333n,
            prevOwner: task4.address,
            forwardPayload: beginCell().storeUint(13, 32).endCell()
        })
        console.log(resCallOwnershipAssigned)

        let t = await task4.getTime()
        console.log('time left', t)

    });
});


