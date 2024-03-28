use array::{ArrayTrait, SpanTrait};
use traits::{Into};



fn compute_hash_on_elements(elements: Array<felt252>) -> felt252 {
    let  mut hash = 0;
    let mut elements_span = elements.span();
    loop {
        match elements_span.pop_front() {
                Option::Some(word) => {
                    hash = core::pedersen::pedersen(hash, *word);
                },
                Option::None(_) => {
                    break;
                }
            };
    };
    let length = elements.len();
    return core::pedersen::pedersen(hash, length.into());
}



