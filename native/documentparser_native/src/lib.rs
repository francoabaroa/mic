use lopdf::Document;
use rustler::{Atom, NifResult};
use std::fs::File;
use std::io::Read;

rustler::init!("Elixir.Mic.Chat.DocumentParser", [parse_pdf, parse_txt]);

mod atoms {
    rustler::atoms! {
        ok,
        error
    }
}

#[rustler::nif]
fn parse_pdf(file_path: String) -> NifResult<(Atom, String)> {
    let doc =
        Document::load(&file_path).map_err(|e| rustler::Error::Term(Box::new(e.to_string())))?;
    let mut text = String::new();

    for (page_number, _) in doc.get_pages() {
        let content = doc
            .extract_text(&[page_number])
            .map_err(|e| rustler::Error::Term(Box::new(e.to_string())))?;
        text.push_str(&content);
    }

    Ok((atoms::ok(), text))
}

#[rustler::nif]
fn parse_txt(file_path: String) -> NifResult<(Atom, String)> {
    let mut file =
        File::open(file_path).map_err(|e| rustler::Error::Term(Box::new(e.to_string())))?;
    let mut text = String::new();
    file.read_to_string(&mut text)
        .map_err(|e| rustler::Error::Term(Box::new(e.to_string())))?;
    Ok((atoms::ok(), text))
}
