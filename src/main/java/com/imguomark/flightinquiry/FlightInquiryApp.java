package com.imguomark.flightinquiry;

import javax.swing.*;
import javax.swing.border.EmptyBorder;
import java.awt.*;
import java.net.URI;
import java.net.http.*;
import java.time.*;
import java.time.format.DateTimeFormatter;
import java.util.*;
import java.util.regex.*;

public final class FlightInquiryApp {
    private final JTextField origin = new JTextField("SFO", 6);
    private final JTextField destination = new JTextField("PVG", 6);
    private final JSpinner passengers = new JSpinner(new SpinnerNumberModel(1, 1, 9, 1));
    private final JTextArea results = new JTextArea();
    private final JLabel status = new JLabel("Enter a route and search for live aircraft activity.");
    private final HttpClient client = HttpClient.newHttpClient();

    public static void main(String[] args) { SwingUtilities.invokeLater(() -> new FlightInquiryApp().show()); }

    private void show() {
        JFrame frame = new JFrame("Flight Inquiry");
        frame.setDefaultCloseOperation(JFrame.EXIT_ON_CLOSE);
        frame.setMinimumSize(new Dimension(720, 520));
        JPanel root = new JPanel(new BorderLayout(14, 14));
        root.setBorder(new EmptyBorder(22, 22, 22, 22));
        JLabel title = new JLabel("Find live aircraft activity");
        title.setFont(title.getFont().deriveFont(Font.BOLD, 26f));
        JPanel top = new JPanel(new BorderLayout(6, 6));
        top.add(title, BorderLayout.NORTH);
        top.add(new JLabel("OpenSky provides aircraft state data; ticket prices are intentionally not shown."), BorderLayout.SOUTH);
        root.add(top, BorderLayout.NORTH);
        JPanel search = new JPanel(new FlowLayout(FlowLayout.LEFT, 10, 4));
        search.add(new JLabel("From")); search.add(origin); search.add(new JLabel("To")); search.add(destination);
        search.add(new JLabel("Passengers")); search.add(passengers);
        JButton button = new JButton("Search"); search.add(button);
        root.add(search, BorderLayout.CENTER);
        results.setEditable(false); results.setFont(new Font(Font.MONOSPACED, Font.PLAIN, 13));
        results.setText("Ready when you are.
");
        root.add(new JScrollPane(results), BorderLayout.SOUTH);
        root.add(status, BorderLayout.PAGE_END);
        button.addActionListener(e -> search(button));
        frame.setContentPane(root); frame.pack(); frame.setLocationByPlatform(true); frame.setVisible(true);
    }

    private void search(JButton button) {
        String from = origin.getText().trim().toUpperCase(Locale.ROOT);
        String to = destination.getText().trim().toUpperCase(Locale.ROOT);
        if (!from.matches("[A-Z]{3}") || !to.matches("[A-Z]{3}")) { status.setText("Use three-letter airport codes, for example SFO and PVG."); return; }
        button.setEnabled(false); status.setText("Searching OpenSky..."); results.setText("");
        new SwingWorker<List<Flight>, Void>() {
            protected List<Flight> doInBackground() throws Exception {
                if ("true".equalsIgnoreCase(System.getenv("FLIGHT_INQUIRY_MOCK"))) return mock(from, to);
                return openSky(from, to);
            }
            protected void done() { button.setEnabled(true); try { List<Flight> fs = get(); render(fs, from, to); } catch (Exception e) { status.setText("Search failed: " + rootMessage(e)); } }
        }.execute();
    }

    private List<Flight> openSky(String from, String to) throws Exception {
        HttpRequest request = HttpRequest.newBuilder(URI.create("https://opensky-network.org/api/states/all")).timeout(Duration.ofSeconds(20)).GET().build();
        HttpResponse<String> response = client.send(request, HttpResponse.BodyHandlers.ofString());
        if (response.statusCode() < 200 || response.statusCode() >= 300) throw new IllegalStateException("OpenSky returned HTTP " + response.statusCode());
        List<Flight> out = new ArrayList<>();
        Matcher m = Pattern.compile("\[(\s*\"[^\"]*\"\s*,.*?\])", Pattern.DOTALL).matcher(response.body());
        while (m.find() && out.size() < 40) {
            String row = m.group(1); List<String> fields = strings(row);
            if (fields.size() < 8) continue;
            String callsign = fields.get(1).trim(); String country = fields.get(2);
            if (callsign.isBlank()) callsign = fields.get(0);
            out.add(new Flight(callsign, country, "Aircraft activity", "Live state vector"));
        }
        return out;
    }

    private List<Flight> mock(String from, String to) {
        return List.of(new Flight("MOCK-" + from + to + "-1", "Demo carrier", "Route-aware offline result", "Mock data"), new Flight("MOCK-" + from + to + "-2", "Demo carrier", "Generated for " + from + " to " + to, "Mock data"));
    }

    private void render(List<Flight> fs, String from, String to) {
        if (fs.isEmpty()) { status.setText("No aircraft activity was returned for " + from + " to " + to + ". OpenSky is not a schedule or booking API."); results.setText("No results.
"); return; }
        status.setText(fs.size() + " aircraft records returned. OpenSky does not guarantee route matching.");
        StringBuilder b = new StringBuilder("Route: ").append(from).append(" -> ").append(to).append("\n\n");
        for (Flight f : fs) b.append(String.format("%-18s %-24s %-24s %s%n", f.id, f.airline, f.detail, f.source));
        results.setText(b.toString());
    }

    private static List<String> strings(String row) { List<String> out = new ArrayList<>(); Matcher m = Pattern.compile("\"((?:\\.|[^\"])*)\"").matcher(row); while (m.find()) out.add(m.group(1)); return out; }
    private static String rootMessage(Exception e) { Throwable t = e; while (t.getCause() != null) t = t.getCause(); return t.getMessage() == null ? t.toString() : t.getMessage(); }
    private record Flight(String id, String airline, String detail, String source) {}
  }
