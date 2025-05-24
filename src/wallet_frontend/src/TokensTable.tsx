import Button from 'react-bootstrap/Button';

export default function TokensTable() {
    return (
        <table id='tokensTable'>
            {/* <thead>
                <tr>
                </tr>
            </thead> */}
            <tbody>
                <tr>
                    <td>ICP</td>
                    <td>Internet Computer</td>
                    <td>1000.00</td>
                    <td><Button>Send</Button> <Button>Receive</Button> <Button>Manage</Button></td>
                </tr>
                <tr>
                    <td>LOREM</td>
                    <td>Lorem Ipsum</td>
                    <td>-</td>
                </tr>
            </tbody>
        </table>
    );
}